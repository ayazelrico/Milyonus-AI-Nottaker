import { randomUUID } from 'node:crypto';
import Fastify from 'fastify';
import type { FastifyInstance, FastifyReply } from 'fastify';
import { bearerToken, createTokenVerifier } from './auth/verify-token.js';
import type { TokenVerifier } from './auth/verify-token.js';
import type { AppConfig } from './config/env.js';
import { writeOperationalEvent } from './observability.js';
import type { EventSink } from './observability.js';

interface AppDependencies {
  readonly verifyToken?: TokenVerifier;
  readonly emit?: EventSink;
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
  if (dependencies.verifyToken !== undefined && config.environment !== 'test') {
    throw new Error('Verifier injection is restricted to tests');
  }

  const verifyToken =
    dependencies.verifyToken ??
    (config.auth === undefined ? undefined : createTokenVerifier(config.auth));
  const emit = dependencies.emit ?? writeOperationalEvent;
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

  app.get('/v1/me', async (request, reply) => {
    if (verifyToken === undefined) {
      return errorResponse(
        reply,
        503,
        'AUTH_UNAVAILABLE',
        'Authentication is not configured.',
        request.id,
      );
    }

    const authorizationCount = request.raw.rawHeaders.filter(
      (header, index) => index % 2 === 0 && header.toLowerCase() === 'authorization',
    ).length;
    const token = authorizationCount === 1 ? bearerToken(request.headers.authorization) : undefined;
    if (token !== undefined) {
      try {
        const identity = await verifyToken(token);
        return { user: { id: identity.id } };
      } catch {
        // Provider failures and invalid tokens both fail closed without exposing their details.
      }
    }

    reply.header('www-authenticate', 'Bearer');
    return errorResponse(reply, 401, 'UNAUTHORIZED', 'Authentication required.', request.id);
  });

  return app;
}
