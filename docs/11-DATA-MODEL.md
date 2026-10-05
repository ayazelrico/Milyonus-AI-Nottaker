# 11 - Data model

The initial development schema is deployed to a dedicated Supabase project in `eu-central-1`. It is
empty and no real transcript data is stored. The backend now has an optional authenticated Data API
adapter for transcript batches. Its migration is applied to development; supplying runtime
configuration and deploying the backend remain deployment steps.

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

The initial schema uses Supabase `auth.users` as identity and does not duplicate credentials in a
public users table. `profiles` stores self-visible application preferences. `workspaces` gain an owner
membership at creation; membership mutations remain backend-only. `meetings` and
`transcript_segments` carry workspace and creator identifiers, indexed foreign keys, constrained
states, and RLS policies. Authenticated users can only access member workspaces. Anonymous users have
no grants on application tables.

The transactional test in `supabase/tests/rls_workspace_isolation.sql` creates two synthetic users and
workspaces, verifies read and write isolation in both directions, checks anonymous grants, and rolls
back all fixtures. The Supabase security advisor has no schema or RLS findings. Its Auth-only warning
reports that leaked-password protection is disabled; the product currently exposes passwordless
Magic Link and OAuth sign-in. The performance advisor only reports unused indexes because all
application tables are intentionally empty.

Local transcript persistence uses GRDB 7.11.1. Segment metadata and revisions are stored in SQLite,
while transcript text is sealed with AES-GCM before every write. A random 256-bit key is generated per
installation and stored in Keychain with this-device-only accessibility. The outbox references the
latest local revision instead of duplicating plaintext. Acknowledgement deletes only the uploaded
revision or an older one, so a correction written during upload remains pending.

`public.upsert_transcript_segments` accepts one to 100 segments, runs with invoker rights, derives
`created_by` from `auth.uid()`, and relies on the existing table grants and RLS policies. Conflict
updates require a higher revision from the original creator and cannot regress a final segment to an
interim segment. Replaying an accepted batch is idempotent.

The synthetic workspace and sample meetings remain in memory. P1-11 owns the bounded rolling audio
buffer, and P1-12 wires persistence into the live meeting composition root.
