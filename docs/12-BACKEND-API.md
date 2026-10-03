# 12 - Backend API

Status: Phase 0 local foundation. No hosted backend or Supabase project has been provisioned.

## Runtime and commands

The backend uses Fastify 5, TypeScript, jose, Vitest, ESLint, and pnpm. Node 24 LTS is the production and CI target. Node 26 is accepted for local verification while it is Current. Dependencies are pinned and the pnpm lockfile must be committed after installation.

Install with `pnpm install --frozen-lockfile` from `backend/`. The workspace configuration keeps the content store and metadata cache inside the repository's ignored `.pnpm-store/` and `.pnpm-cache/` directories. Only the reviewed `esbuild@0.28.2` install script is allowed; dependency updates that introduce a new script or version require review. Commands fail on stale dependencies instead of automatically installing packages.

From `backend/`, use `pnpm dev` for development, `pnpm build` to compile, and `pnpm start` to run the built server. Validation is `pnpm typecheck`, `pnpm test`, and `pnpm lint`. The lint command also checks formatting; `pnpm format` formats owned backend files.

The application factory does not load files or open a listening socket. The process entry point loads only `backend/.env.local`, independent of the current working directory, without overriding environment variables supplied by the host. `.env.example` contains empty values only. Never commit or print `.env.local`.

## Configuration

| Variable | Behavior |
| --- | --- |
| `NODE_ENV` | `development` by default; accepts only `development`, `test`, or `production`. |
| `HOST` | `127.0.0.1` by default. Accepts an IP address or `localhost`; explicitly use `0.0.0.0` behind a trusted deployment ingress. |
| `PORT` | `3000` by default; an integer from 1 through 65535. |
| `AUTH_ISSUER` | Exact HTTPS issuer ending in `/auth/v1`, without trailing slash, credentials, query, or fragment. |
| `AUTH_AUDIENCE` | Exact expected audience, normally `authenticated`. |

Both auth fields may be absent during local development, which keeps liveness available and authentication unavailable. Partial configuration always fails startup. Production requires both fields. The JWKS URL is derived from the trusted issuer by appending `/.well-known/jwks.json`; a request cannot select the issuer or keys. Provider secrets are reserved in the empty template but are not required, exposed, or consumed by Phase 0.

Model identifiers are centralized in `backend/src/config/models.ts`. Provider integration and prompts are not implemented in this phase.

## Endpoints

| Method and path | Access | Result |
| --- | --- | --- |
| `GET /health` | Public | `200 {"status":"ok"}`. Liveness only; this is not a database/provider readiness check. |
| `GET /v1/me` | Valid access token | `200 {"user":{"id":"<UUID>"}}`. No profile, email, workspace, subscription, or credential data. |

Protected requests carry exactly one `Authorization: Bearer <JWT>` header. Duplicate raw headers are rejected as a malformed request before verification. Tokens in cookies or query strings are not accepted. Responses have `Cache-Control: no-store`, `X-Content-Type-Options: nosniff`, and a server-generated `X-Request-Id`. Client request IDs are ignored.

Errors use `{"error":{"code":"<CODE>","message":"<GENERIC_MESSAGE>"},"requestId":"<UUID>"}`:

- `401 UNAUTHORIZED`: missing, malformed, expired, or rejected credentials, including verifier failures. Includes `WWW-Authenticate: Bearer`.
- `503 AUTH_UNAVAILABLE`: local authentication configuration is absent.
- `404 NOT_FOUND`: unknown route. The requested path is not echoed.
- `4xx INVALID_REQUEST`: malformed or oversized input. No parser details are returned.
- `500 INTERNAL_ERROR`: unexpected request failure. No stack trace, provider message, or request content is returned.

## Authentication boundary

JWT signatures use the configured project's public JWKS keys and an explicit `ES256`/`RS256` algorithm allowlist. Verification requires issuer, audience, subject, expiry, issued-at, role, and anonymous-status claims. The subject must be a non-nil RFC UUID, role must be `authenticated`, and `is_anonymous` must be boolean `false`. Issued-at cannot be in the future; expiry must be a safe integer later than issued-at and must not have elapsed. No clock leeway is enabled. User-editable `user_metadata` is never used for authorization.

The backend does not accept legacy `HS256`, unsigned tokens, service-role tokens, or anonymous-user tokens. There is no development bypass or fake session. Replacing the verifier through the application factory is restricted to `NODE_ENV=test`, and the production entry point never injects it.

The remote key lookup has a five-second timeout, a thirty-second refresh cooldown, and a ten-minute in-memory cache. Supabase also caches its discovery endpoint. Key revocation and sign-out are not immediately observable through offline JWT validation. This endpoint establishes signed identity only. Workspace membership/RLS, session revocation checks for sensitive operations, and subscription authorization are later work, not implied by the `authenticated` role. Urgent key revocation requires the provider's incident procedure and refreshing backend instances/caches.

## Privacy and operations

Fastify logging is disabled entirely. Operational output is projected onto a small allowlist: server start with port, startup/shutdown failure, or request failure with a generated request ID and status code. Request URLs, headers, bodies, tokens, audio, transcripts, user profile fields, errors, and stack traces are never emitted. The entry point reports configuration failure without printing environment values.

The local HTTP listener binds to loopback by default. Production deployment must provide HTTPS ingress and configure its own access logs to exclude authorization and content. Public deployment, rate limiting, readiness probes, storage, paid provider calls, and billing are outside this local task.

## Verification

Tests generate local asymmetric key pairs and verify real signed tokens without external network requests. They cover issuer/audience/signature failures, expiry and required claims, anonymous and privileged roles, both supported signing algorithms, unsupported symmetric/unsigned tokens, missing configuration, production guardrails, header parsing, route behavior, and error/log redaction. Key discovery tests intercept fetch to verify trusted URL selection, caching, and unavailable-provider rejection. A loopback HTTP test checks duplicate raw Authorization headers through Node's real parser. Tests do not read `.env.local` or use real credentials.

## Provider references verified 2026-10-02

- [Supabase changelog](https://supabase.com/changelog): reviewed before implementation. The self-hosted issuer-path change is consistent with the explicit `/auth/v1` issuer; no hosted JWT verification change required a different design.
- [Supabase JWT verification](https://supabase.com/docs/guides/auth/jwts) and [JWT claims](https://supabase.com/docs/guides/auth/jwt-fields): issuer-derived JWKS and claim semantics.
- [Supabase signing keys](https://supabase.com/docs/guides/auth/signing-keys): supported asymmetric algorithms, discovery caching, and rotation limitations.
- [Node release status](https://nodejs.org/en/about/previous-releases): Node 24 is LTS; Node 26 is Current.
- [Fastify server options](https://fastify.dev/docs/latest/Reference/Server/): logging, request IDs, and request limits.
- [jose verification](https://github.com/panva/jose/blob/main/docs/jwt/verify/functions/jwtVerify.md): signature and claims validation API.
