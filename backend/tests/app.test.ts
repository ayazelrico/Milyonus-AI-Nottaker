import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT } from 'jose';
import { request as httpRequest } from 'node:http';
import type { FastifyInstance } from 'fastify';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { buildApp } from '../src/app.js';
import { createTokenVerifier } from '../src/auth/verify-token.js';
import { parseConfig } from '../src/config/env.js';
import type { OperationalEvent } from '../src/observability.js';

const testConfig = parseConfig({ NODE_ENV: 'test' });
const userId = '44757ce8-0661-49d0-aaf7-4567e0808c0a';
const apps: FastifyInstance[] = [];

function track(app: FastifyInstance): FastifyInstance {
  apps.push(app);
  return app;
}

afterEach(async () => {
  await Promise.all(apps.splice(0).map((app) => app.close()));
});

describe('HTTP foundation', () => {
  it('provides liveness without credentials but leaves authentication unavailable', async () => {
    const app = track(buildApp(testConfig));
    const health = await app.inject({ method: 'GET', url: '/health' });
    expect(health.statusCode).toBe(200);
    expect(health.json()).toEqual({ status: 'ok' });
    const me = await app.inject({ method: 'GET', url: '/v1/me' });
    expect(me.statusCode).toBe(503);
    expect(me.json()).toMatchObject({ error: { code: 'AUTH_UNAVAILABLE' } });
  });

  it('returns minimal identity from a cryptographically verified access token', async () => {
    const config = parseConfig({
      NODE_ENV: 'test',
      AUTH_ISSUER: 'https://project.supabase.co/auth/v1',
      AUTH_AUDIENCE: 'authenticated',
    });
    if (config.auth === undefined) throw new Error('Test auth config is required');
    const pair = await generateKeyPair('ES256');
    const jwk = await exportJWK(pair.publicKey);
    const verifyToken = createTokenVerifier(
      config.auth,
      createLocalJWKSet({ keys: [{ ...jwk, kid: 'http-test', alg: 'ES256' }] }),
    );
    const token = await new SignJWT({ role: 'authenticated', is_anonymous: false })
      .setProtectedHeader({ alg: 'ES256', kid: 'http-test' })
      .setIssuer(config.auth.issuer)
      .setAudience(config.auth.audience)
      .setSubject(userId)
      .setIssuedAt()
      .setExpirationTime('5m')
      .sign(pair.privateKey);
    const app = track(buildApp(config, { verifyToken }));
    const result = await app.inject({
      method: 'GET',
      url: '/v1/me',
      headers: { authorization: `Bearer ${token}` },
    });
    expect(result.statusCode).toBe(200);
    expect(result.json()).toEqual({ user: { id: userId } });
    expect(result.headers['cache-control']).toBe('no-store');
  });

  it('rejects missing, malformed, query-string, and cookie credentials before verification', async () => {
    const verifyToken = vi.fn().mockResolvedValue({ id: userId });
    const app = track(buildApp(testConfig, { verifyToken }));
    for (const options of [
      { url: '/v1/me' },
      { url: '/v1/me', headers: { authorization: 'Basic fake' } },
      {
        url: '/v1/me',
        headers: { authorization: 'Bearer abc.def.ghi, Bearer jkl.mno.pqr' },
      },
      { url: '/v1/me?access_token=abc.def.ghi' },
      { url: '/v1/me', headers: { cookie: 'access_token=abc.def.ghi' } },
    ]) {
      const result = await app.inject({ method: 'GET', ...options });
      expect(result.statusCode).toBe(401);
      expect(result.headers['www-authenticate']).toBe('Bearer');
    }
    expect(verifyToken).not.toHaveBeenCalled();
  });

  it('rejects duplicate Authorization headers before token verification', async () => {
    const verifyToken = vi.fn().mockResolvedValue({ id: userId });
    const app = track(buildApp(testConfig, { verifyToken }));
    const address = await app.listen({ host: '127.0.0.1', port: 0 });
    const status = await new Promise<number>((resolve, reject) => {
      const request = httpRequest(
        `${address}/v1/me`,
        {
          method: 'GET',
          headers: ['Authorization', 'Bearer abc.def.ghi', 'Authorization', 'Bearer jkl.mno.pqr'],
        },
        (response) => {
          response.resume();
          response.once('end', () => resolve(response.statusCode ?? 0));
          response.once('error', reject);
        },
      );
      request.once('error', reject);
      request.end();
    });
    // Node rejects duplicate singleton headers as a malformed request before Fastify can authorize it.
    expect(status).toBe(400);
    expect(verifyToken).not.toHaveBeenCalled();
  });

  it('fails closed if the verifier rejects and hides provider details', async () => {
    const events: OperationalEvent[] = [];
    const app = track(
      buildApp(testConfig, {
        verifyToken: () => Promise.reject(new Error('private-provider-fixture')),
        emit: (event) => events.push(event),
      }),
    );
    const result = await app.inject({
      method: 'GET',
      url: '/v1/me',
      headers: { authorization: 'Bearer abc.def.ghi' },
    });
    expect(result.statusCode).toBe(401);
    expect(result.body).not.toContain('private-provider-fixture');
    expect(JSON.stringify(events)).not.toContain('abc.def.ghi');
    expect(JSON.stringify(events)).not.toContain('private-provider-fixture');
  });

  it('refuses verifier replacement outside test mode', () => {
    for (const NODE_ENV of ['development', 'production']) {
      const config = parseConfig({
        NODE_ENV,
        AUTH_ISSUER: 'https://project.supabase.co/auth/v1',
        AUTH_AUDIENCE: 'authenticated',
      });
      expect(() =>
        buildApp(config, { verifyToken: () => Promise.resolve({ id: userId }) }),
      ).toThrow('Dependency injection is restricted to tests');
    }
  });

  it('issues a short-lived STT token after auth, consent, and entitlement checks', async () => {
    const verifyToken = vi.fn().mockResolvedValue({ id: userId });
    const checkEntitlement = vi.fn().mockResolvedValue(true);
    const issueSttToken = vi.fn().mockResolvedValue({
      accessToken: 'header.payload.signature',
      expiresIn: 30,
    });
    const app = track(buildApp(testConfig, { verifyToken, checkEntitlement, issueSttToken }));

    const result = await app.inject({
      method: 'POST',
      url: '/v1/stt/token',
      headers: { authorization: 'Bearer abc.def.ghi' },
      payload: { consentConfirmed: true },
    });

    expect(result.statusCode).toBe(200);
    expect(result.json()).toEqual({
      provider: 'deepgram',
      accessToken: 'header.payload.signature',
      tokenType: 'Bearer',
      expiresIn: 30,
    });
    expect(checkEntitlement).toHaveBeenCalledWith({ id: userId });
    expect(issueSttToken).toHaveBeenCalledOnce();
    expect(result.headers['cache-control']).toBe('no-store');
  });

  it('does not evaluate consent, entitlement, or STT before authentication', async () => {
    const checkEntitlement = vi.fn().mockResolvedValue(true);
    const issueSttToken = vi.fn();
    const app = track(buildApp(testConfig, { checkEntitlement, issueSttToken }));
    const result = await app.inject({
      method: 'POST',
      url: '/v1/stt/token',
      payload: { consentConfirmed: true },
    });
    expect(result.statusCode).toBe(503);
    expect(result.json()).toMatchObject({ error: { code: 'AUTH_UNAVAILABLE' } });
    expect(checkEntitlement).not.toHaveBeenCalled();
    expect(issueSttToken).not.toHaveBeenCalled();
  });

  it.each([
    undefined,
    {},
    { consentConfirmed: false },
    { consentConfirmed: true, ignored: true },
    'true',
  ])('requires an exact positive consent assertion before entitlement: %j', async (payload) => {
    const checkEntitlement = vi.fn();
    const issueSttToken = vi.fn();
    const app = track(
      buildApp(testConfig, {
        verifyToken: () => Promise.resolve({ id: userId }),
        checkEntitlement,
        issueSttToken,
      }),
    );
    const result = await app.inject({
      method: 'POST',
      url: '/v1/stt/token',
      headers:
        payload === undefined
          ? { authorization: 'Bearer abc.def.ghi' }
          : {
              authorization: 'Bearer abc.def.ghi',
              'content-type': 'application/json',
            },
      ...(payload === undefined ? {} : { payload }),
    });
    expect(result.statusCode).toBe(409);
    expect(result.json()).toMatchObject({ error: { code: 'CONSENT_REQUIRED' } });
    expect(checkEntitlement).not.toHaveBeenCalled();
    expect(issueSttToken).not.toHaveBeenCalled();
  });

  it('rejects an account without entitlement before contacting the STT provider', async () => {
    const issueSttToken = vi.fn();
    const app = track(
      buildApp(testConfig, {
        verifyToken: () => Promise.resolve({ id: userId }),
        checkEntitlement: () => Promise.resolve(false),
        issueSttToken,
      }),
    );
    const result = await app.inject({
      method: 'POST',
      url: '/v1/stt/token',
      headers: { authorization: 'Bearer abc.def.ghi' },
      payload: { consentConfirmed: true },
    });
    expect(result.statusCode).toBe(403);
    expect(result.json()).toMatchObject({ error: { code: 'ENTITLEMENT_REQUIRED' } });
    expect(issueSttToken).not.toHaveBeenCalled();
  });

  it('returns a redacted unavailable response when STT is unconfigured or fails', async () => {
    const providerError = 'private-provider-fixture';
    const events: OperationalEvent[] = [];
    const baseDependencies = {
      verifyToken: () => Promise.resolve({ id: userId }),
      emit: (event: OperationalEvent) => events.push(event),
    };
    const unconfigured = track(buildApp(testConfig, baseDependencies));
    const failed = track(
      buildApp(testConfig, {
        ...baseDependencies,
        issueSttToken: () => Promise.reject(new Error(providerError)),
      }),
    );
    const options = {
      method: 'POST' as const,
      url: '/v1/stt/token',
      headers: { authorization: 'Bearer abc.def.ghi' },
      payload: { consentConfirmed: true },
    };
    const unconfiguredResult = await unconfigured.inject(options);
    const failedResult = await failed.inject(options);
    expect(unconfiguredResult.statusCode).toBe(503);
    expect(failedResult.statusCode).toBe(503);
    expect(unconfiguredResult.json()).toMatchObject({ error: { code: 'STT_UNAVAILABLE' } });
    expect(failedResult.json()).toMatchObject({ error: { code: 'STT_UNAVAILABLE' } });
    expect(failedResult.body + JSON.stringify(events)).not.toContain(providerError);
  });

  it('redacts thrown errors, request content and client-provided request IDs', async () => {
    const events: OperationalEvent[] = [];
    const app = track(buildApp(testConfig, { emit: (event) => events.push(event) }));
    app.post('/test-failure', () => {
      throw new Error('private-error-fixture');
    });
    const result = await app.inject({
      method: 'POST',
      url: '/test-failure?transcript=private-query-fixture',
      headers: {
        authorization: 'Bearer abc.def.ghi',
        'x-request-id': 'private-id-fixture',
      },
      payload: { transcript: 'private-transcript-fixture' },
    });
    expect(result.statusCode).toBe(500);
    expect(result.headers['x-request-id']).toMatch(/^[0-9a-f-]{36}$/);
    expect(result.json()).toMatchObject({ error: { code: 'INTERNAL_ERROR' } });
    expect(events).toEqual([
      {
        event: 'request_failed',
        requestId: result.headers['x-request-id'],
        statusCode: 500,
      },
    ]);
    expect(result.body + JSON.stringify(events)).not.toMatch(/private-|abc\.def\.ghi/);
  });

  it('does not expose input when rejecting invalid JSON or an unknown path', async () => {
    const events: OperationalEvent[] = [];
    const app = track(buildApp(testConfig, { emit: (event) => events.push(event) }));
    app.post('/test-json', () => ({ status: 'ok' }));
    const result = await app.inject({
      method: 'POST',
      url: '/test-json',
      headers: { 'content-type': 'application/json' },
      payload: '{"transcript":private-body-fixture}',
    });
    const missing = await app.inject({ method: 'GET', url: '/private-path-fixture' });
    expect(result.statusCode).toBe(400);
    expect(missing.statusCode).toBe(404);
    expect(result.body + missing.body + JSON.stringify(events)).not.toContain('private-');
  });

  it('redacts a malformed URL before the normal request lifecycle starts', async () => {
    const app = track(buildApp(testConfig));
    const result = await app.inject({ method: 'GET', url: '/private-%FF-fixture' });
    expect(result.statusCode).toBe(400);
    expect(result.json()).toMatchObject({ error: { code: 'INVALID_REQUEST' } });
    expect(result.body).not.toContain('private-');
  });
});
