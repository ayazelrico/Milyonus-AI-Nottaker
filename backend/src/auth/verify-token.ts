import { createRemoteJWKSet, jwtVerify } from 'jose';
import type { JWTVerifyGetKey } from 'jose';
import type { AuthConfig } from '../config/env.js';

export interface Identity {
  readonly id: string;
}

export type TokenVerifier = (token: string) => Promise<Identity>;

export class InvalidTokenError extends Error {
  constructor() {
    super('Invalid access token');
    this.name = 'InvalidTokenError';
  }
}

const userIdPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** The optional resolver lets cryptographic tests use local public keys without network access. */
export function createTokenVerifier(config: AuthConfig, resolver?: JWTVerifyGetKey): TokenVerifier {
  const keys =
    resolver ??
    createRemoteJWKSet(new URL(config.jwksUrl), {
      timeoutDuration: 5_000,
      cooldownDuration: 30_000,
      cacheMaxAge: 600_000,
    });

  return async (token) => {
    const { payload } = await jwtVerify(token, keys, {
      issuer: config.issuer,
      audience: config.audience,
      algorithms: ['ES256', 'RS256'],
      requiredClaims: ['sub', 'exp', 'iat', 'role', 'is_anonymous'],
      clockTolerance: 0,
    });

    if (
      typeof payload.sub !== 'string' ||
      !userIdPattern.test(payload.sub) ||
      payload.role !== 'authenticated' ||
      payload.is_anonymous !== false ||
      !Number.isSafeInteger(payload.exp) ||
      !Number.isSafeInteger(payload.iat) ||
      (payload.iat ?? Infinity) > Math.floor(Date.now() / 1000) ||
      (payload.exp ?? 0) <= (payload.iat ?? Infinity)
    ) {
      throw new InvalidTokenError();
    }

    return Object.freeze({ id: payload.sub.toLowerCase() });
  };
}

/** Accept only one compact JWT in the Authorization header, never query parameters. */
export function bearerToken(header: string | undefined): string | undefined {
  if (header === undefined || header.length > 8_192) return undefined;
  return /^Bearer ([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/i.exec(header)?.[1];
}
