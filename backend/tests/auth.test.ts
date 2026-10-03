import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT } from 'jose';
import type { webcrypto } from 'node:crypto';
import type { JWK, JWTPayload } from 'jose';
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { bearerToken, createTokenVerifier } from '../src/auth/verify-token.js';
import type { TokenVerifier } from '../src/auth/verify-token.js';

const issuer = 'https://project.supabase.co/auth/v1';
const userId = '44757ce8-0661-49d0-aaf7-4567e0808c0a';
const config = { issuer, audience: 'authenticated', jwksUrl: `${issuer}/.well-known/jwks.json` };
let privateKey: webcrypto.CryptoKey;
let publicKey: JWK;
let verify: TokenVerifier;

beforeAll(async () => {
  const pair = await generateKeyPair('ES256');
  privateKey = pair.privateKey;
  publicKey = await exportJWK(pair.publicKey);
  verify = createTokenVerifier(
    config,
    createLocalJWKSet({ keys: [{ ...publicKey, kid: 'local-test-key', alg: 'ES256' }] }),
  );
});

afterEach(() => vi.unstubAllGlobals());

function validClaims(): JWTPayload {
  const now = Math.floor(Date.now() / 1000);
  return {
    iss: issuer,
    aud: 'authenticated',
    sub: userId,
    iat: now - 1,
    exp: now + 300,
    role: 'authenticated',
    is_anonymous: false,
  };
}

function sign(claims: JWTPayload): Promise<string> {
  return new SignJWT(claims)
    .setProtectedHeader({ alg: 'ES256', kid: 'local-test-key', typ: 'JWT' })
    .sign(privateKey);
}

describe('asymmetric access-token verification', () => {
  it('verifies a real signature and returns only a canonical user ID', async () => {
    const token = await sign({
      ...validClaims(),
      sub: userId.toUpperCase(),
      email: 'private-fixture@example.invalid',
      user_metadata: { role: 'admin' },
    });
    await expect(verify(token)).resolves.toEqual({ id: userId });
  });

  it.each([
    { iss: 'https://other.supabase.co/auth/v1' },
    { aud: 'wrong-audience' },
    { sub: 'not-a-uuid' },
    { sub: '00000000-0000-0000-0000-000000000000' },
    { role: 'service_role' },
    { role: 'anon', user_metadata: { role: 'authenticated' } },
    { is_anonymous: true },
    { is_anonymous: 'false' },
    { exp: 1 },
    { exp: 1.5 },
    { iat: 9_999_999_999 },
    { nbf: 9_999_999_999 },
  ])('rejects incorrect trusted claims: %j', async (claims) => {
    await expect(verify(await sign({ ...validClaims(), ...claims }))).rejects.toThrow();
  });

  it.each(['iss', 'aud', 'sub', 'exp', 'iat', 'role', 'is_anonymous'])(
    'rejects a missing required claim: %s',
    async (claim) => {
      const claims = validClaims();
      delete claims[claim];
      await expect(verify(await sign(claims))).rejects.toThrow();
    },
  );

  it('rejects a signature from an untrusted key', async () => {
    const other = await generateKeyPair('ES256');
    const token = await new SignJWT(validClaims())
      .setProtectedHeader({ alg: 'ES256', kid: 'local-test-key' })
      .sign(other.privateKey);
    await expect(verify(token)).rejects.toThrow();
  });

  it('rejects unsupported symmetric and unsigned tokens', async () => {
    const token = await new SignJWT(validClaims())
      .setProtectedHeader({ alg: 'HS256', kid: 'local-test-key' })
      .sign(new Uint8Array(32));
    await expect(verify(token)).rejects.toThrow();
    await expect(verify('eyJhbGciOiJub25lIn0.e30.')).rejects.toThrow();
  });

  it('also verifies supported RSA tokens through the same claim checks', async () => {
    const pair = await generateKeyPair('RS256');
    const key = await exportJWK(pair.publicKey);
    const rsa = createTokenVerifier(
      config,
      createLocalJWKSet({ keys: [{ ...key, kid: 'rsa-test-key', alg: 'RS256' }] }),
    );
    const token = await new SignJWT(validClaims())
      .setProtectedHeader({ alg: 'RS256', kid: 'rsa-test-key' })
      .sign(pair.privateKey);
    await expect(rsa(token)).resolves.toEqual({ id: userId });
  });

  it('fetches keys only from configured JWKS and caches them, ignoring token-supplied key URLs', async () => {
    const fetchKeys = vi
      .fn()
      .mockResolvedValue(
        Response.json({ keys: [{ ...publicKey, kid: 'local-test-key', alg: 'ES256' }] }),
      );
    vi.stubGlobal('fetch', fetchKeys);
    const remote = createTokenVerifier(config);
    const token = await new SignJWT(validClaims())
      .setProtectedHeader({
        alg: 'ES256',
        kid: 'local-test-key',
        jku: 'https://untrusted.example.invalid/keys',
      })
      .sign(privateKey);
    await expect(remote(token)).resolves.toEqual({ id: userId });
    await expect(remote(token)).resolves.toEqual({ id: userId });
    expect(fetchKeys).toHaveBeenCalledExactlyOnceWith(
      config.jwksUrl,
      expect.objectContaining({ method: 'GET', redirect: 'manual' }),
    );
  });

  it('does not authenticate if key discovery is unavailable', async () => {
    const fetchKeys = vi.fn().mockRejectedValue(new Error('Key server unavailable'));
    vi.stubGlobal('fetch', fetchKeys);
    await expect(createTokenVerifier(config)(await sign(validClaims()))).rejects.toThrow();
    expect(fetchKeys).toHaveBeenCalledTimes(1);
  });
});

describe('Authorization header parsing', () => {
  it('supports a single case-insensitive Bearer scheme', () => {
    expect(bearerToken('Bearer abc.def.ghi')).toBe('abc.def.ghi');
    expect(bearerToken('bearer abc.def.ghi')).toBe('abc.def.ghi');
  });

  it.each([
    undefined,
    '',
    'Basic abc.def.ghi',
    'Bearer fake-token',
    'Bearer  abc.def.ghi',
    'Bearer abc.def.ghi ',
    'Bearer abc.def.',
    'Bearer abc.def.ghi, Bearer abc.def.ghi',
    `Bearer ${'a'.repeat(8_192)}.def.ghi`,
  ])('rejects malformed or oversized credentials', (header) => {
    expect(bearerToken(header)).toBeUndefined();
  });
});
