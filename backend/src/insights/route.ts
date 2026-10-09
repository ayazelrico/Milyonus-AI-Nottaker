import { randomUUID } from 'node:crypto';
import { Readable } from 'node:stream';
import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import type { Identity } from '../auth/verify-token.js';
import type { EntitlementChecker } from '../entitlements/check-entitlement.js';
import type { EventSink } from '../observability.js';
import type { InsightGenerator } from './service.js';
import { parseInsightInput } from './service.js';

interface RouteDependencies {
  readonly authenticate: (
    request: FastifyRequest,
    reply: FastifyReply,
  ) => Promise<{ readonly identity: Identity } | undefined>;
  readonly checkEntitlement: EntitlementChecker;
  readonly emit: EventSink;
  readonly generate: InsightGenerator | undefined;
}

function failure(
  reply: FastifyReply,
  requestId: string,
  status: number,
  code: string,
  message: string,
) {
  return reply.code(status).send({ error: { code, message }, requestId });
}

function event(name: string, data: unknown): string {
  return `event: ${name}\ndata: ${JSON.stringify(data)}\n\n`;
}

/** Process-local development safeguards, not distributed billing or abuse enforcement. */
class RequestLimiter {
  private readonly callers = new Map<string, { active: boolean; nextAllowed: number }>();
  private activeCount = 0;

  acquire(id: string): (() => void) | undefined {
    const now = Date.now();
    for (const [key, caller] of this.callers) {
      if (!caller.active && caller.nextAllowed <= now) this.callers.delete(key);
    }
    const previous = this.callers.get(id);
    if (
      this.activeCount >= 8 ||
      this.callers.size >= 1000 ||
      previous?.active === true ||
      (previous?.nextAllowed ?? 0) > now
    )
      return undefined;
    const caller = { active: true, nextAllowed: now };
    this.callers.set(id, caller);
    this.activeCount += 1;
    let released = false;
    return () => {
      if (released) return;
      released = true;
      this.activeCount -= 1;
      caller.active = false;
      caller.nextAllowed = Date.now() + 2000;
    };
  }
}

export function registerInsightRoute(app: FastifyInstance, dependencies: RouteDependencies): void {
  const limiter = new RequestLimiter();
  app.post('/v1/insights/stream', async (request, reply) => {
    const authenticated = await dependencies.authenticate(request, reply);
    if (authenticated === undefined) return;
    if (
      typeof request.body !== 'object' ||
      request.body === null ||
      !('consentConfirmed' in request.body) ||
      request.body.consentConfirmed !== true
    ) {
      return failure(
        reply,
        request.id,
        409,
        'CONSENT_REQUIRED',
        'Meeting consent must be confirmed.',
      );
    }
    const input = parseInsightInput(request.body);
    if (input === undefined) {
      return failure(reply, request.id, 400, 'INVALID_INSIGHT_INPUT', 'Insight input is invalid.');
    }
    if (!(await dependencies.checkEntitlement(authenticated.identity))) {
      return failure(
        reply,
        request.id,
        403,
        'ENTITLEMENT_REQUIRED',
        'An active entitlement is required.',
      );
    }
    const generate = dependencies.generate;
    if (generate === undefined) {
      return failure(reply, request.id, 503, 'INSIGHTS_UNAVAILABLE', 'Insights are unavailable.');
    }
    const release = limiter.acquire(authenticated.identity.id);
    if (release === undefined) {
      reply.header('retry-after', '2');
      return failure(
        reply,
        request.id,
        429,
        'INSIGHT_RATE_LIMITED',
        'Please wait before requesting another insight.',
      );
    }
    const controller = new AbortController();
    const signal = AbortSignal.any([controller.signal, AbortSignal.timeout(12_000)]);
    const started = performance.now();
    const cancel = () => controller.abort();
    const close = () => {
      if (!reply.raw.writableFinished) cleanup();
    };
    const cleanup = () => {
      clearTimeout(connectionDeadline);
      cancel();
      release();
      request.raw.removeListener('aborted', cancel);
      reply.raw.removeListener('close', close);
      reply.raw.removeListener('finish', cleanup);
    };
    request.raw.once('aborted', cancel);
    reply.raw.once('close', close);
    reply.raw.once('finish', cleanup);

    const events = async function* (): AsyncGenerator<string> {
      try {
        yield event('started', { requestId: request.id });
        let hasCard = false;
        let completed = false;
        for await (const value of generate(input, signal)) {
          signal.throwIfAborted();
          switch (value.type) {
            case 'progress':
              yield event('progress', {
                requestId: request.id,
                receivedCharacters: value.receivedCharacters,
              });
              break;
            case 'card':
              if (hasCard) throw new Error('Duplicate insight');
              hasCard = true;
              yield event('card', {
                requestId: request.id,
                id: randomUUID(),
                ...value.card,
                promptVersion: value.promptVersion,
                grounding: 'transcript_only',
              });
              break;
            case 'completed':
              dependencies.emit({
                event: 'llm_completed',
                requestId: request.id,
                durationMilliseconds: Math.round(performance.now() - started),
                attempts: value.attempts,
                ...value.usage,
              });
              completed = true;
              break;
          }
        }
        if (!hasCard || !completed) throw new Error('Incomplete insight');
        yield event('done', { requestId: request.id });
      } catch {
        if (!controller.signal.aborted) {
          dependencies.emit({ event: 'request_failed', requestId: request.id, statusCode: 503 });
          yield event('error', {
            error: { code: 'INSIGHTS_UNAVAILABLE', message: 'Insights are unavailable.' },
            requestId: request.id,
          });
        }
      } finally {
        cleanup();
      }
    };
    const stream = Readable.from(events(), { objectMode: false, highWaterMark: 2048 });
    stream.once('close', cleanup);
    // Bound the response lifetime even while a slow reader pauses the generator at a yield.
    const connectionDeadline = setTimeout(() => {
      cleanup();
      stream.destroy();
      reply.raw.destroy();
    }, 12_000);
    connectionDeadline.unref();
    if (request.raw.aborted || reply.raw.destroyed) {
      cleanup();
      stream.destroy();
    }
    reply.header('x-accel-buffering', 'no');
    reply.type('text/event-stream; charset=utf-8');
    return reply.send(stream);
  });
}
