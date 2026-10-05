import { randomUUID } from 'node:crypto';
import Fastify from 'fastify';
import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { bearerToken, createTokenVerifier } from './auth/verify-token.js';
import type { Identity, TokenVerifier } from './auth/verify-token.js';
import type { AppConfig } from './config/env.js';
import { allowAuthenticatedEntitlement } from './entitlements/check-entitlement.js';
import type { EntitlementChecker } from './entitlements/check-entitlement.js';
import { writeOperationalEvent } from './observability.js';
import type { EventSink } from './observability.js';
import { createDeepgramTokenIssuer } from './stt/deepgram-token-issuer.js';
import type { SttTokenIssuer } from './stt/deepgram-token-issuer.js';

interface AppDependencies {
  readonly verifyToken?: TokenVerifier;
  readonly emit?: EventSink;
  readonly checkEntitlement?: EntitlementChecker;
  readonly issueSttToken?: SttTokenIssuer;
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
      dependencies.issueSttToken !== undefined) &&
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
  const app = Fastify({
    logger: false,
    requestIdHeader: false,
    genReqId: () => randomUUID(),
    bodyLimit: 16_384,
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
  ): Promise<Identity | undefined> {
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
        return await verifyToken(token);
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
    return { user: { id: identity.id } };
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

    if (!(await checkEntitlement(identity))) {
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

  return app;
}
