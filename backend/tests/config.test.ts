import { describe, expect, it } from 'vitest';
import { ConfigurationError, parseConfig } from '../src/config/env.js';

const auth = {
  AUTH_ISSUER: 'https://project.supabase.co/auth/v1',
  AUTH_AUDIENCE: 'authenticated',
};

describe('configuration', () => {
  it('supports a credential-free local health service and treats empty template fields as absent', () => {
    expect(
      parseConfig({ NODE_ENV: '', PORT: '', HOST: '', AUTH_ISSUER: '', AUTH_AUDIENCE: '' }),
    ).toEqual({
      environment: 'development',
      host: '127.0.0.1',
      port: 3000,
      auth: undefined,
      deepgram: undefined,
      supabaseData: undefined,
    });
  });

  it('derives a trusted JWKS URL and ignores unrelated provider secrets', () => {
    const config = parseConfig({
      NODE_ENV: 'production',
      HOST: '0.0.0.0',
      PORT: '8080',
      ...auth,
      STRIPE_SECRET_KEY: 'sensitive-fixture',
    });
    expect(config).toEqual({
      environment: 'production',
      host: '0.0.0.0',
      port: 8080,
      auth: {
        issuer: auth.AUTH_ISSUER,
        audience: auth.AUTH_AUDIENCE,
        jwksUrl: `${auth.AUTH_ISSUER}/.well-known/jwks.json`,
      },
      deepgram: undefined,
      anthropic: undefined,
      supabaseData: undefined,
    });
    expect(JSON.stringify(config)).not.toContain('sensitive-fixture');
    expect(Object.isFrozen(config)).toBe(true);
  });

  it('accepts an Anthropic key and rejects malformed ones without echoing them', () => {
    const config = parseConfig({ ANTHROPIC_API_KEY: 'valid-anthropic-key-fixture' });
    expect(config.anthropic).toEqual({ apiKey: 'valid-anthropic-key-fixture' });
    expect(Object.isFrozen(config.anthropic)).toBe(true);
    expect(() => parseConfig({ ANTHROPIC_API_KEY: 'short' })).toThrow('ANTHROPIC_API_KEY');
    expect(() => parseConfig({ ANTHROPIC_API_KEY: 'has space in the key value' })).toThrow(
      'ANTHROPIC_API_KEY',
    );
    expect(parseConfig({}).anthropic).toBeUndefined();
  });

  it('accepts a Deepgram key without exposing it in configuration errors', () => {
    const config = parseConfig({ DEEPGRAM_API_KEY: 'valid-deepgram-key-fixture' });
    expect(config.deepgram).toEqual({ apiKey: 'valid-deepgram-key-fixture' });
    expect(Object.isFrozen(config.deepgram)).toBe(true);

    for (const DEEPGRAM_API_KEY of ['short', 'contains whitespace fixture']) {
      expect(() => parseConfig({ DEEPGRAM_API_KEY })).toThrow('DEEPGRAM_API_KEY');
      try {
        parseConfig({ DEEPGRAM_API_KEY });
      } catch (error) {
        expect(String(error)).not.toContain(DEEPGRAM_API_KEY);
      }
    }
  });

  it('accepts a complete Supabase Data API configuration and rejects partial or unsafe values', () => {
    const config = parseConfig({
      SUPABASE_URL: 'https://project.supabase.co',
      SUPABASE_PUBLISHABLE_KEY: 'publishable-key-fixture-value',
    });
    expect(config.supabaseData).toEqual({
      url: 'https://project.supabase.co',
      publishableKey: 'publishable-key-fixture-value',
    });
    expect(Object.isFrozen(config.supabaseData)).toBe(true);

    expect(() => parseConfig({ SUPABASE_URL: 'https://project.supabase.co' })).toThrow(
      'SUPABASE_PUBLISHABLE_KEY',
    );
    expect(() =>
      parseConfig({ SUPABASE_PUBLISHABLE_KEY: 'publishable-key-fixture-value' }),
    ).toThrow('SUPABASE_URL');
    for (const SUPABASE_URL of [
      'http://project.supabase.co',
      'https://project.supabase.co/rest/v1',
      'https://name:private-fixture@project.supabase.co',
    ]) {
      expect(() =>
        parseConfig({
          SUPABASE_URL,
          SUPABASE_PUBLISHABLE_KEY: 'publishable-key-fixture-value',
        }),
      ).toThrow('SUPABASE_URL');
    }
  });

  it.each(['staging', 'PRODUCTION', 'unknown'])(
    'rejects an unknown environment: %s',
    (NODE_ENV) => {
      expect(() => parseConfig({ NODE_ENV })).toThrow('NODE_ENV');
    },
  );

  it.each(['0', '-1', '65536', '3000junk', '1.5', '1e3', 'NaN', 'Infinity'])(
    'rejects an invalid port: %s',
    (PORT) => {
      expect(() => parseConfig({ PORT })).toThrow('PORT');
    },
  );

  it.each(['https://localhost', '127.0.0.999', 'any interface'])(
    'rejects an invalid host: %s',
    (HOST) => {
      expect(() => parseConfig({ HOST })).toThrow('HOST');
    },
  );

  it.each([
    'http://project.supabase.co/auth/v1',
    'https://project.supabase.co',
    'https://project.supabase.co/auth/v1/',
    'https://name:sensitive-fixture@project.supabase.co/auth/v1',
    'https://project.supabase.co/auth/v1?secret=sensitive-fixture',
    'https://project.supabase.co/auth/v1#sensitive-fixture',
    'not a URL sensitive-fixture',
  ])('rejects unsafe issuers without echoing the configured value', (AUTH_ISSUER) => {
    expect(() => parseConfig({ ...auth, AUTH_ISSUER })).toThrow('AUTH_ISSUER');
    try {
      parseConfig({ ...auth, AUTH_ISSUER });
    } catch (error) {
      expect(error).toBeInstanceOf(ConfigurationError);
      expect(String(error)).not.toContain('sensitive-fixture');
    }
  });

  it('requires complete auth configuration and always requires it in production', () => {
    expect(() => parseConfig({ AUTH_ISSUER: auth.AUTH_ISSUER })).toThrow('AUTH_AUDIENCE');
    expect(() => parseConfig({ AUTH_AUDIENCE: auth.AUTH_AUDIENCE })).toThrow('AUTH_ISSUER');
    expect(() => parseConfig({ NODE_ENV: 'production' })).toThrow('AUTH_ISSUER');
    expect(() => parseConfig({ ...auth, AUTH_AUDIENCE: 'spaces are unsafe' })).toThrow(
      'AUTH_AUDIENCE',
    );
  });
});
