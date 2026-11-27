import { isIP } from 'node:net';

export type Environment = 'development' | 'test' | 'production';

export interface AuthConfig {
  readonly issuer: string;
  readonly audience: string;
  readonly jwksUrl: string;
}

export interface DeepgramConfig {
  readonly apiKey: string;
}

export interface AnthropicConfig {
  readonly apiKey: string;
}

export interface SupabaseDataConfig {
  readonly url: string;
  readonly publishableKey: string;
}

export interface AppConfig {
  readonly environment: Environment;
  readonly host: string;
  readonly port: number;
  readonly auth: AuthConfig | undefined;
  readonly deepgram: DeepgramConfig | undefined;
  readonly anthropic: AnthropicConfig | undefined;
  readonly supabaseData: SupabaseDataConfig | undefined;
}

export class ConfigurationError extends Error {
  constructor(readonly field: string) {
    super(`Invalid configuration: ${field}`);
    this.name = 'ConfigurationError';
  }
}

type EnvironmentValues = Readonly<Record<string, string | undefined>>;

function value(env: EnvironmentValues, key: string): string | undefined {
  const raw = env[key]?.trim();
  return raw === '' ? undefined : raw;
}

function authConfig(env: EnvironmentValues, environment: Environment): AuthConfig | undefined {
  const issuer = value(env, 'AUTH_ISSUER');
  const audience = value(env, 'AUTH_AUDIENCE');

  if (issuer === undefined && audience === undefined && environment !== 'production') {
    return undefined;
  }

  if (issuer === undefined) throw new ConfigurationError('AUTH_ISSUER');
  if (audience === undefined || !/^[A-Za-z0-9._:-]{1,128}$/.test(audience)) {
    throw new ConfigurationError('AUTH_AUDIENCE');
  }

  let url: URL;
  try {
    url = new URL(issuer);
  } catch {
    throw new ConfigurationError('AUTH_ISSUER');
  }

  if (
    url.protocol !== 'https:' ||
    url.username !== '' ||
    url.password !== '' ||
    url.search !== '' ||
    url.hash !== '' ||
    url.pathname !== '/auth/v1' ||
    url.href !== issuer
  ) {
    throw new ConfigurationError('AUTH_ISSUER');
  }

  return Object.freeze({
    issuer,
    audience,
    jwksUrl: `${issuer}/.well-known/jwks.json`,
  });
}

function deepgramConfig(env: EnvironmentValues): DeepgramConfig | undefined {
  const apiKey = value(env, 'DEEPGRAM_API_KEY');
  if (apiKey === undefined) return undefined;
  const hasUnsafeCharacter = Array.from(apiKey).some((character) => {
    const codePoint = character.codePointAt(0) ?? 0;
    return codePoint <= 32 || codePoint === 127;
  });
  if (apiKey.length < 16 || apiKey.length > 512 || hasUnsafeCharacter) {
    throw new ConfigurationError('DEEPGRAM_API_KEY');
  }

  return Object.freeze({ apiKey });
}

function anthropicConfig(env: EnvironmentValues): AnthropicConfig | undefined {
  const apiKey = value(env, 'ANTHROPIC_API_KEY');
  if (apiKey === undefined) return undefined;
  const hasUnsafeCharacter = Array.from(apiKey).some((character) => {
    const codePoint = character.codePointAt(0) ?? 0;
    return codePoint <= 32 || codePoint === 127;
  });
  if (apiKey.length < 16 || apiKey.length > 512 || hasUnsafeCharacter) {
    throw new ConfigurationError('ANTHROPIC_API_KEY');
  }

  return Object.freeze({ apiKey });
}

function supabaseDataConfig(env: EnvironmentValues): SupabaseDataConfig | undefined {
  const configuredUrl = value(env, 'SUPABASE_URL');
  const publishableKey = value(env, 'SUPABASE_PUBLISHABLE_KEY');
  if (configuredUrl === undefined && publishableKey === undefined) {
    return undefined;
  }
  if (configuredUrl === undefined) throw new ConfigurationError('SUPABASE_URL');
  if (publishableKey === undefined) throw new ConfigurationError('SUPABASE_PUBLISHABLE_KEY');

  let url: URL;
  try {
    url = new URL(configuredUrl);
  } catch {
    throw new ConfigurationError('SUPABASE_URL');
  }
  if (
    url.protocol !== 'https:' ||
    url.username !== '' ||
    url.password !== '' ||
    url.pathname !== '/' ||
    url.search !== '' ||
    url.hash !== '' ||
    url.href !== `${url.origin}/`
  ) {
    throw new ConfigurationError('SUPABASE_URL');
  }
  const hasUnsafeKeyCharacter = Array.from(publishableKey).some((character) => {
    const codePoint = character.codePointAt(0) ?? 0;
    return codePoint <= 32 || codePoint === 127;
  });
  if (publishableKey.length < 20 || publishableKey.length > 2048 || hasUnsafeKeyCharacter) {
    throw new ConfigurationError('SUPABASE_PUBLISHABLE_KEY');
  }
  return Object.freeze({ url: url.origin, publishableKey });
}

/** Pure parsing only. Loading .env.local belongs to the process entry point. */
export function parseConfig(env: EnvironmentValues): AppConfig {
  const environment = value(env, 'NODE_ENV') ?? 'development';
  if (!['development', 'test', 'production'].includes(environment)) {
    throw new ConfigurationError('NODE_ENV');
  }

  const host = value(env, 'HOST') ?? '127.0.0.1';
  if (host !== 'localhost' && isIP(host) === 0) throw new ConfigurationError('HOST');

  const portString = value(env, 'PORT') ?? '3000';
  const port = Number(portString);
  if (!/^\d{1,5}$/.test(portString) || !Number.isInteger(port) || port < 1 || port > 65535) {
    throw new ConfigurationError('PORT');
  }

  return Object.freeze({
    environment: environment as Environment,
    host,
    port,
    auth: authConfig(env, environment as Environment),
    deepgram: deepgramConfig(env),
    anthropic: anthropicConfig(env),
    supabaseData: supabaseDataConfig(env),
  });
}
