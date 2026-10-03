# 11 - Data model

Reconstructed design direction. No cloud schema or real transcript persistence is deployed in Phase 0.

Account identity comes from the auth provider. Domain entities are workspace, membership, profile,
meeting, transcript segment, summary, action item, document, chunk, and usage event. All owned content
must carry a workspace identifier. Do not create a second password/credential store in a public users
table. Clarify the supplied roadmap's users table as an application profile linked to auth identity.

Segments have immutable IDs, meeting/channel identity, monotonic offsets, finality, and revision
semantics. Writes must be idempotent. Summaries track model/prompt version and source revisions.
Usage events deduplicate by operation identity and must not depend on client-reported totals.

Before migrations: specify columns and constraints, tenant policies, indexes, deletion behavior,
retention, and migration rollback strategy in P0-06. Apply RLS to exposed tables and test users from
different workspaces. SQL policy tests must run against a real isolated test database. Do not mark
schema acceptance based solely on migration file inspection.

Local persistence is deferred. Encrypt real transcript text, protect keys in Keychain, and bound
rolling audio buffers. The synthetic workspace remains in memory; only UI preferences persist now.
