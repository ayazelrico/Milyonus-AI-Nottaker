# P0-06 - Supabase foundation

Status: completed on 2026-10-03. The owner approved the existing organization and Frankfurt region.
Supabase reported a monthly project cost of USD 0 before provisioning.

## Goal

Create the first tenant-isolated data layer without storing credentials in the repository. Supabase
Auth owns account identity in `auth.users`; `public.profiles` stores application profile data. Every
meeting and transcript row is bound to a workspace, and all exposed tables use Row Level Security.

## Plan

1. Create a dedicated development project. Do not reuse the existing Milyonus AI Interview project.
2. Add a reviewed migration for profiles, workspaces, memberships, meetings, and transcript segments.
3. Add indexed membership helpers in an unexposed schema and explicit RLS policies for authenticated
   users. Anonymous access remains denied.
4. Apply the migration through Supabase, execute cross-workspace isolation tests in a transaction,
   and run security and performance advisors.
5. Generate TypeScript database types, record the project reference without credentials, update the
   data model and roadmap, then run the repository checks before commit and push.

## Security and rollback

- Authorization derives from `auth.uid()` and database membership rows, never user-editable metadata.
- The client receives no service-role credential. Backend-only privileged access will be added with a
  separate server configuration task.
- Transcript content is protected by RLS but is not claimed to have application-level encryption yet.
  Production retention, export, and deletion behavior remain release blockers.
- The initial migration is additive. Before real data exists, rollback is deletion of the dedicated
  development project. Later schema changes must use forward migrations instead of destructive reset.

## Acceptance

- A dedicated development project is active in the approved region.
- The committed migration matches remote migration history.
- Anonymous access has no table grants.
- Two synthetic users in separate workspaces cannot read or write each other's meetings or transcript
  segments in the transactional RLS test.
- Supabase security and performance advisors have no unresolved findings caused by this migration.

## Verification

- Project `qfjrhbzxjxavzyvrvtiv` is active and healthy in `eu-central-1`.
- Remote migration versions `20261003135317` and `20261003135414` match committed files.
- Five public application tables have RLS enabled and remain empty after the transactional test.
- The two-user isolation test passed without leaving fixture rows.
- Security advisor returned no findings. The foreign-key index finding was fixed in the second
  migration; remaining performance notices are unused-index information on empty tables.
