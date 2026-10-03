# Supabase development database

The dedicated development project is `Milyonus AI Nottaker Development` in Frankfurt
(`eu-central-1`). Its non-secret project reference is `qfjrhbzxjxavzyvrvtiv` and API URL is
`https://qfjrhbzxjxavzyvrvtiv.supabase.co`.

The repository contains migration history and transactional RLS verification under `migrations/`
and `tests/`. Apply schema changes as named migrations, run the isolation test against an isolated
development database, then run Supabase security and performance advisors. Test fixtures are
synthetic and roll back in the same transaction.

Do not commit publishable keys, service-role keys, access tokens, database passwords, or local link
state. Runtime credentials belong in ignored local environment files or deployment secret stores.
The service-role key is backend-only and must never enter the macOS application.
