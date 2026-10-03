# P0-04 - Backend foundation

Status: implementation authorized by the owner on 2026-10-02.

## Goal and requirements

Create a Fastify/TypeScript backend with deterministic configuration, public liveness, protected identity, and tests. Covers FR-03 authenticated backend and NFR-02 credential isolation.

## Plan

1. Pin runtime and development dependencies and configure pnpm, TypeScript, ESLint, and Vitest.
2. Load environment configuration explicitly. Keep the health endpoint available without provider credentials; reject unsafe production configuration.
3. Verify Supabase-compatible asymmetric JWTs through a configured issuer and JWKS URL. Validate audience, subject, expiration, and authenticated role. Missing auth configuration fails closed.
4. Add GET /health and GET /v1/me with generic, non-sensitive errors. Disable request-content logging and use metadata-only operational logs.
5. Test valid and invalid tokens using locally generated test keys, config failures, redaction, and endpoint behavior. Build and lint.

## Scope and risks

No cloud resources, real sessions, migrations, paid AI calls, or deployment are created. Auth UI and refresh belong to P0-07. Reject unsupported legacy HS256 rather than adding a client-shared secret. Model IDs live only in config. No prompt content is added in this task.
