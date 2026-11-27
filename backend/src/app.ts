import { randomUUID } from 'node:crypto';
import type { OutgoingHttpHeaders } from 'node:http';
import Fastify from 'fastify';
import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { bearerToken, createTokenVerifier } from './auth/verify-token.js';
import type { Identity, TokenVerifier } from './auth/verify-token.js';
import type { AppConfig } from './config/env.js';
import { allowAuthenticatedEntitlement } from './entitlements/check-entitlement.js';
import type { EntitlementChecker } from './entitlements/check-entitlement.js';
import { classifyTrigger } from './insights/classify-trigger.js';
import { generateInsight, InsightError } from './insights/generate-insight.js';
import { parseClassifyRequest, parseInsightRequest } from './insights/schemas.js';
import { createAnthropicProvider } from './llm/anthropic-provider.js';
import type { LlmProvider } from './llm/types.js';
import { writeOperationalEvent } from './observability.js';
import type { EventSink } from './observability.js';
import { createDeepgramTokenIssuer } from './stt/deepgram-token-issuer.js';
import type { SttTokenIssuer } from './stt/deepgram-token-issuer.js';
import { createSupabaseSegmentWriter } from './transcript/supabase-segment-writer.js';
import type {
  TranscriptBatchInput,
  TranscriptSegmentInput,
  TranscriptSegmentWriter,
} from './transcript/supabase-segment-writer.js';

interface AppDependencies {
  readonly verifyToken?: TokenVerifier;
  readonly emit?: EventSink;
  readonly checkEntitlement?: EntitlementChecker;
  readonly issueSttToken?: SttTokenIssuer;
  readonly writeTranscriptSegments?: TranscriptSegmentWriter;
  readonly llmProvider?: LlmProvider;
}

interface AuthenticatedRequest {
  readonly identity: Identity;
  readonly accessToken: string;
}

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function transcriptBatch(body: unknown): TranscriptBatchInput | undefined {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) return undefined;
  const candidate = body as Record<string, unknown>;
  if (
    Object.keys(candidate).length !== 3 ||
    typeof candidate.workspaceId !== 'string' ||
    !uuidPattern.test(candidate.workspaceId) ||
    typeof candidate.meetingId !== 'string' ||
    !uuidPattern.test(candidate.meetingId) ||
    !Array.isArray(candidate.segments) ||
    candidate.segments.length < 1 ||
    candidate.segments.length > 100
  ) {
    return undefined;
  }

  const segments: TranscriptSegmentInput[] = [];
  const segmentIDs = new Set<string>();
  for (const value of candidate.segments) {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) return undefined;
    const segment = value as Record<string, unknown>;
    if (
      Object.keys(segment).length !== 7 ||
      typeof segment.id !== 'string' ||
      !uuidPattern.test(segment.id) ||
      (segment.channel !== 'microphone' && segment.channel !== 'system') ||
      typeof segment.text !== 'string' ||
      segment.text.length < 1 ||
      segment.text.length > 10_000 ||
      typeof segment.startMilliseconds !== 'number' ||
      !Number.isSafeInteger(segment.startMilliseconds) ||
      segment.startMilliseconds < 0 ||
      typeof segment.endMilliseconds !== 'number' ||
      !Number.isSafeInteger(segment.endMilliseconds) ||
      segment.endMilliseconds < segment.startMilliseconds ||
      typeof segment.isFinal !== 'boolean' ||
      typeof segment.revision !== 'number' ||
      !Number.isSafeInteger(segment.revision) ||
      segment.revision < 1
    ) {
      return undefined;
    }
    const normalizedID = segment.id.toLowerCase();
    if (segmentIDs.has(normalizedID)) return undefined;
    segmentIDs.add(normalizedID);
    segments.push(segment as unknown as TranscriptSegmentInput);
  }
  return {
    workspaceId: candidate.workspaceId.toLowerCase(),
    meetingId: candidate.meetingId.toLowerCase(),
    segments,
  };
}

function errorResponse(
  reply: FastifyReply,
  status: number,
  code: string,
  message: string,
  requestId: string,
) {
  return reply.code(status).send({ error: { code, message }, requestId });
}

export function buildApp(config: AppConfig, dependencies: AppDependencies = {}): FastifyInstance {
  if (
    (dependencies.verifyToken !== undefined ||
      dependencies.checkEntitlement !== undefined ||
      dependencies.issueSttToken !== undefined ||
      dependencies.writeTranscriptSegments !== undefined ||
      dependencies.llmProvider !== undefined) &&
    config.environment !== 'test'
  ) {
    throw new Error('Dependency injection is restricted to tests');
  }

  const verifyToken =
    dependencies.verifyToken ??
    (config.auth === undefined ? undefined : createTokenVerifier(config.auth));
  const emit = dependencies.emit ?? writeOperationalEvent;
  const checkEntitlement = dependencies.checkEntitlement ?? allowAuthenticatedEntitlement;
  const issueSttToken =
    dependencies.issueSttToken ??
    (config.deepgram === undefined ? undefined : createDeepgramTokenIssuer(config.deepgram));
  const writeTranscriptSegments =
    dependencies.writeTranscriptSegments ??
    (config.supabaseData === undefined
      ? undefined
      : createSupabaseSegmentWriter(config.supabaseData));
  const llmProvider =
    dependencies.llmProvider ??
    (config.anthropic === undefined ? undefined : createAnthropicProvider(config.anthropic));
  const app = Fastify({
    logger: false,
    requestIdHeader: false,
    genReqId: () => randomUUID(),
    bodyLimit: 262_144,
    requestTimeout: 15_000,
    connectionTimeout: 15_000,
    trustProxy: false,
    frameworkErrors: (_error, request, reply) => {
      reply.header('x-request-id', request.id);
      reply.header('cache-control', 'no-store');
      reply.header('x-content-type-options', 'nosniff');
      void errorResponse(reply, 400, 'INVALID_REQUEST', 'Invalid request.', request.id);
    },
  });

  app.addHook('onRequest', (request, reply, done) => {
    reply.header('x-request-id', request.id);
    reply.header('cache-control', 'no-store');
    reply.header('x-content-type-options', 'nosniff');
    done();
  });

  app.setErrorHandler((error, request, reply) => {
    const candidateStatus =
      typeof error === 'object' && error !== null && 'statusCode' in error
        ? error.statusCode
        : undefined;
    const statusCode =
      typeof candidateStatus === 'number' &&
      Number.isInteger(candidateStatus) &&
      candidateStatus >= 400 &&
      candidateStatus < 500
        ? candidateStatus
        : 500;
    const isClientError = statusCode < 500;
    emit({ event: 'request_failed', requestId: request.id, statusCode });
    return errorResponse(
      reply,
      statusCode,
      isClientError ? 'INVALID_REQUEST' : 'INTERNAL_ERROR',
      isClientError ? 'Invalid request.' : 'Request could not be completed.',
      request.id,
    );
  });

  app.setNotFoundHandler((request, reply) =>
    errorResponse(reply, 404, 'NOT_FOUND', 'Route not found.', request.id),
  );

  app.get('/health', () => ({ status: 'ok' }));

  async function authenticate(
    request: FastifyRequest,
    reply: FastifyReply,
  ): Promise<AuthenticatedRequest | undefined> {
    if (verifyToken === undefined) {
      errorResponse(
        reply,
        503,
        'AUTH_UNAVAILABLE',
        'Authentication is not configured.',
        request.id,
      );
      return undefined;
    }

    const authorizationCount = request.raw.rawHeaders.filter(
      (header, index) => index % 2 === 0 && header.toLowerCase() === 'authorization',
    ).length;
    const token = authorizationCount === 1 ? bearerToken(request.headers.authorization) : undefined;
    if (token !== undefined) {
      try {
        return { identity: await verifyToken(token), accessToken: token };
      } catch {
        // Provider failures and invalid tokens both fail closed without exposing their details.
      }
    }

    reply.header('www-authenticate', 'Bearer');
    errorResponse(reply, 401, 'UNAUTHORIZED', 'Authentication required.', request.id);
    return undefined;
  }

  app.get('/v1/me', async (request, reply) => {
    const identity = await authenticate(request, reply);
    if (identity === undefined) return;
    return { user: { id: identity.identity.id } };
  });

  app.post('/v1/stt/token', async (request, reply) => {
    const identity = await authenticate(request, reply);
    if (identity === undefined) return;

    const body = request.body;
    if (
      typeof body !== 'object' ||
      body === null ||
      Array.isArray(body) ||
      Object.keys(body).length !== 1 ||
      !('consentConfirmed' in body) ||
      body.consentConfirmed !== true
    ) {
      return errorResponse(
        reply,
        409,
        'CONSENT_REQUIRED',
        'Meeting consent must be confirmed.',
        request.id,
      );
    }

    if (!(await checkEntitlement(identity.identity))) {
      return errorResponse(
        reply,
        403,
        'ENTITLEMENT_REQUIRED',
        'An active entitlement is required.',
        request.id,
      );
    }

    if (issueSttToken === undefined) {
      return errorResponse(
        reply,
        503,
        'STT_UNAVAILABLE',
        'Transcription is unavailable.',
        request.id,
      );
    }

    try {
      const token = await issueSttToken();
      return {
        provider: 'deepgram',
        accessToken: token.accessToken,
        tokenType: 'Bearer',
        expiresIn: token.expiresIn,
      };
    } catch {
      emit({ event: 'request_failed', requestId: request.id, statusCode: 503 });
      return errorResponse(
        reply,
        503,
        'STT_UNAVAILABLE',
        'Transcription is unavailable.',
        request.id,
      );
    }
  });

  app.put('/v1/transcript/segments:batch', async (request, reply) => {
    const authenticated = await authenticate(request, reply);
    if (authenticated === undefined) return;
    const batch = transcriptBatch(request.body);
    if (batch === undefined) {
      return errorResponse(
        reply,
        400,
        'INVALID_SEGMENT_BATCH',
        'Segment batch is invalid.',
        request.id,
      );
    }
    if (writeTranscriptSegments === undefined) {
      return errorResponse(
        reply,
        503,
        'TRANSCRIPT_SYNC_UNAVAILABLE',
        'Transcript sync is unavailable.',
        request.id,
      );
    }
    try {
      const accepted = await writeTranscriptSegments(
        authenticated.identity,
        authenticated.accessToken,
        batch,
      );
      return { accepted };
    } catch {
      emit({ event: 'request_failed', requestId: request.id, statusCode: 503 });
      return errorResponse(
        reply,
        503,
        'TRANSCRIPT_SYNC_UNAVAILABLE',
        'Transcript sync is unavailable.',
        request.id,
      );
    }
  });

  app.post('/v1/insights/stream', async (request, reply) => {
    const authenticated = await authenticate(request, reply);
    if (authenticated === undefined) return;

    const insightRequest = parseInsightRequest(request.body);
    if (insightRequest === undefined) {
      return errorResponse(
        reply,
        400,
        'INVALID_INSIGHT_REQUEST',
        'Insight request is invalid.',
        request.id,
      );
    }

    if (!(await checkEntitlement(authenticated.identity))) {
      return errorResponse(
        reply,
        403,
        'ENTITLEMENT_REQUIRED',
        'An active entitlement is required.',
        request.id,
      );
    }

    if (llmProvider === undefined) {
      return errorResponse(
        reply,
        503,
        'INSIGHTS_UNAVAILABLE',
        'Insights are unavailable.',
        request.id,
      );
    }

    // Server-sent events. The stream carries validated cards only, never raw model output.
    const controller = new AbortController();
    reply.raw.once('close', () => {
      if (!reply.raw.writableEnded) controller.abort();
    });
    reply.hijack();
    reply.raw.writeHead(200, {
      ...(reply.getHeaders() as OutgoingHttpHeaders),
      'content-type': 'text/event-stream; charset=utf-8',
      'cache-control': 'no-store',
      connection: 'keep-alive',
      'x-accel-buffering': 'no',
    });
    const send = (event: string, data: unknown): void => {
      reply.raw.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
    };

    send('started', { requestId: request.id });
    try {
      const result = await generateInsight(llmProvider, insightRequest, controller.signal);
      emit({
        event: 'insight_generated',
        requestId: request.id,
        model: result.model,
        inputTokens: result.usage.inputTokens,
        outputTokens: result.usage.outputTokens,
      });
      send('insight', result.card);
      send('done', {});
    } catch (error) {
      const code = error instanceof InsightError ? error.code : 'INSIGHT_UNAVAILABLE';
      emit({ event: 'request_failed', requestId: request.id, statusCode: 503 });
      send('error', { code });
    } finally {
      reply.raw.end();
    }
  });

  app.post('/v1/triggers/classify', async (request, reply) => {
    const authenticated = await authenticate(request, reply);
    if (authenticated === undefined) return;

    const classifyRequest = parseClassifyRequest(request.body);
    if (classifyRequest === undefined) {
      return errorResponse(
        reply,
        400,
        'INVALID_CLASSIFY_REQUEST',
        'Classification request is invalid.',
        request.id,
      );
    }

    if (!(await checkEntitlement(authenticated.identity))) {
      return errorResponse(
        reply,
        403,
        'ENTITLEMENT_REQUIRED',
        'An active entitlement is required.',
        request.id,
      );
    }

    if (llmProvider === undefined) {
      return errorResponse(
        reply,
        503,
        'CLASSIFIER_UNAVAILABLE',
        'Classification is unavailable.',
        request.id,
      );
    }

    const controller = new AbortController();
    reply.raw.once('close', () => {
      if (!reply.raw.writableEnded) controller.abort();
    });
    try {
      const result = await classifyTrigger(llmProvider, classifyRequest, controller.signal);
      emit({
        event: 'insight_generated',
        requestId: request.id,
        model: result.model,
        inputTokens: result.usage.inputTokens,
        outputTokens: result.usage.outputTokens,
      });
      return result.classification;
    } catch {
      emit({ event: 'request_failed', requestId: request.id, statusCode: 503 });
      return errorResponse(
        reply,
        503,
        'CLASSIFIER_UNAVAILABLE',
        'Classification is unavailable.',
        request.id,
      );
    }
  });

  return app;
}
