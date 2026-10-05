import { describe, expect, it, vi } from 'vitest';
import {
  createDeepgramTokenIssuer,
  SttProviderUnavailableError,
} from '../src/stt/deepgram-token-issuer.js';

const apiKey = 'private-deepgram-key-fixture';

describe('Deepgram token issuer', () => {
  it('calls the fixed grant endpoint with a 30-second TTL and returns validated fields', async () => {
    const request = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ access_token: 'header.payload.signature', expires_in: 30 }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      }),
    );
    const issue = createDeepgramTokenIssuer({ apiKey }, request);
    await expect(issue()).resolves.toEqual({
      accessToken: 'header.payload.signature',
      expiresIn: 30,
    });
    expect(request).toHaveBeenCalledOnce();
    const [url, options] = request.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://api.deepgram.com/v1/auth/grant');
    expect(options.method).toBe('POST');
    expect(options.body).toBe('{"ttl_seconds":30}');
    expect(options.headers).toMatchObject({
      authorization: `Token ${apiKey}`,
      'content-type': 'application/json',
    });
  });

  it.each([
    [401, { err_msg: 'private-provider-fixture' }],
    [200, { access_token: 'not-a-jwt', expires_in: 30 }],
    [200, { access_token: 'header.payload.signature', expires_in: 0 }],
    [200, { access_token: 'header.payload.signature', expires_in: 3601 }],
    [200, { access_token: 'header.payload.signature', expires_in: '30' }],
    [200, {}],
  ])('fails closed for provider status or payload: %s %j', async (status, body) => {
    const request = vi.fn().mockResolvedValue(
      new Response(JSON.stringify(body), {
        status,
        headers: { 'content-type': 'application/json' },
      }),
    );
    const issue = createDeepgramTokenIssuer({ apiKey }, request);
    await expect(issue()).rejects.toBeInstanceOf(SttProviderUnavailableError);
  });

  it('maps network and invalid JSON failures to a generic provider error', async () => {
    const networkIssue = createDeepgramTokenIssuer(
      { apiKey },
      vi.fn().mockRejectedValue(new Error('private-network-fixture')),
    );
    const invalidJsonIssue = createDeepgramTokenIssuer(
      { apiKey },
      vi.fn().mockResolvedValue(new Response('private-invalid-json-fixture', { status: 200 })),
    );
    await expect(networkIssue()).rejects.toBeInstanceOf(SttProviderUnavailableError);
    await expect(invalidJsonIssue()).rejects.toBeInstanceOf(SttProviderUnavailableError);
  });
});
