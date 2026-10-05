import type { DeepgramConfig } from '../config/env.js';

const grantUrl = 'https://api.deepgram.com/v1/auth/grant';
const tokenPattern = /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/;

export interface SttAccessToken {
  readonly accessToken: string;
  readonly expiresIn: number;
}

export type SttTokenIssuer = () => Promise<SttAccessToken>;

export class SttProviderUnavailableError extends Error {
  constructor() {
    super('STT provider unavailable');
    this.name = 'SttProviderUnavailableError';
  }
}

interface DeepgramGrantResponse {
  readonly access_token?: unknown;
  readonly expires_in?: unknown;
}

function isGrantResponse(value: unknown): value is DeepgramGrantResponse {
  return typeof value === 'object' && value !== null;
}

/** Calls the fixed Deepgram grant endpoint without exposing the permanent API key. */
export function createDeepgramTokenIssuer(
  config: DeepgramConfig,
  request: typeof fetch = fetch,
): SttTokenIssuer {
  return async () => {
    let response: Response;
    try {
      response = await request(grantUrl, {
        method: 'POST',
        headers: {
          accept: 'application/json',
          authorization: `Token ${config.apiKey}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({ ttl_seconds: 30 }),
        signal: AbortSignal.timeout(5_000),
      });
    } catch {
      throw new SttProviderUnavailableError();
    }

    if (!response.ok) throw new SttProviderUnavailableError();

    try {
      const body: unknown = await response.json();
      if (
        !isGrantResponse(body) ||
        typeof body.access_token !== 'string' ||
        body.access_token.length > 8_192 ||
        !tokenPattern.test(body.access_token) ||
        !Number.isSafeInteger(body.expires_in) ||
        (body.expires_in as number) < 1 ||
        (body.expires_in as number) > 3_600
      ) {
        throw new SttProviderUnavailableError();
      }
      return Object.freeze({
        accessToken: body.access_token,
        expiresIn: body.expires_in as number,
      });
    } catch (error) {
      if (error instanceof SttProviderUnavailableError) throw error;
      throw new SttProviderUnavailableError();
    }
  };
}
