# Backend area guide

Read [../AGENTS.md](../AGENTS.md), [../docs/02-ARCHITECTURE.md](../docs/02-ARCHITECTURE.md), and [../docs/12-BACKEND-API.md](../docs/12-BACKEND-API.md).

- Keep the HTTP application factory separate from process startup and environment loading.
- Validate trusted configuration before listening. Authentication must fail closed.
- Request headers, URLs, payloads, JWTs, provider errors, transcripts, and audio must never be logged.
- Use the allowlisted operational event types. Do not enable Fastify's automatic logger.
- Keep model IDs in `src/config/models.ts` and prompts in the repository's `prompts/` directory.
- Use generated local keys and Fastify injection for tests. No real sessions or paid provider calls.
- Run `pnpm typecheck`, `pnpm build`, `pnpm test`, and `pnpm lint` after backend changes.
