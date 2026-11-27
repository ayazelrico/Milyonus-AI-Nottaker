# Legal groundwork (P0-10 draft)

Engineering draft for owner and lawyer review. This is not legal advice and not a compliance claim.
Nothing here is verified against provider contracts. Every "Verify" item must be checked in the
provider's current terms before any production claim.

## 1. Data map (target state, v1)

| Data | Where it originates | Where it goes | Stored where | Retention (proposed) | Notes |
|---|---|---|---|---|---|
| Meeting audio (mic + system) | Device | STT provider via short-lived token, direct stream | Local rolling buffer only | Minutes, deleted after backfill | Never uploaded to our backend |
| Transcript text | STT provider | App, then backend batch upload | Local encrypted GRDB, Supabase (RLS) | User-controlled, default TBD | Never logged |
| Transcript snippets for insights | App | Backend, then LLM provider | Not stored by default | Request lifetime | Provider retention terms apply |
| Summaries, action items, emails | LLM provider | Backend, then app | Supabase | Same as meeting | |
| KB documents and chunks | User upload | Backend, embedding provider | Supabase storage and pgvector | Until user deletes | Untrusted content |
| Account identity (email, user id) | User | Supabase Auth | Supabase, Keychain (session) | Until account deletion | |
| Calendar events | EventKit / Google | App / backend | Minimal metadata | Until disconnected | Phase 5 |
| Billing data | User | Stripe | Stripe | Per Stripe and tax law | Phase 6 |
| Diagnostics | App | Sentry (opt-in) | Sentry | Short | Scrubbed, opt-in |

Current Phase 0 reality: see "Phase 0 data map" in `14-SECURITY-PRIVACY-LEGAL.md`. No meeting content
leaves the device yet.

## 2. Provider terms checklist (all items must be verified)

For each provider, record the date checked and the source URL in the table at the end.

- **Anthropic (LLM):** Verify data retention default, zero data retention availability, training on
  API data, region options, DPA availability, subprocessors.
- **Deepgram (STT):** Verify retention of audio and transcripts, model training opt-out
  (including the data-use setting), ZDR or equivalent, EN and TR language support, region, DPA.
- **AssemblyAI (secondary STT):** Same questions as Deepgram.
- **Embedding provider (Voyage or alternative):** Verify training use, retention, TR quality, DPA.
- **Supabase:** Verify region (Frankfurt approved for dev), DPA, backups, subprocessors.
- **Stripe:** Verify entity requirements, tax handling, data processing terms.
- **Sentry:** Verify scrubbing options, data residency, DPA.
- **Hosting provider (undecided):** Verify region and DPA before selection.

| Provider | Date checked | Source URL | Retention | Training use | ZDR | DPA | Result |
|---|---|---|---|---|---|---|---|
| Anthropic | not checked | | | | | | open |
| Deepgram | not checked | | | | | | open |
| AssemblyAI | not checked | | | | | | open |
| Embeddings | not checked | | | | | | open |
| Supabase | not checked | | | | | | open |
| Stripe | not checked | | | | | | open |
| Sentry | not checked | | | | | | open |
| Hosting | not chosen | | | | | | open |

## 3. Contracting entity decision (OWNER REQUIRED)

Options to decide, with lawyer input:

1. Milyonus legal entity as controller and merchant of record for the app.
2. A separate product entity.
3. Individual (not recommended for a subscription business with user data).

Dependent decisions: Apple Developer Program account holder, Stripe account holder, DPA signatory,
KVKK data controller registration (VERBIS) applicability, GDPR representative if serving EU users.
This draft does not pick an option. Record the outcome as a new ADR in `03-DECISIONS.md`.

## 4. Consent and recording law (open questions for counsel)

- Two-party or all-party consent jurisdictions and what notice the app must show.
- Whether the app must announce recording to other participants.
- Turkish KVKK explicit consent wording for voice and transcript data.
- Children, employee-monitoring, and healthcare or legal meeting restrictions.

## 5. Documents still to be written after the entity is chosen

Privacy policy, ToS, DPA, KVKK notice, subprocessor list (all P6-08, with lawyer review).

## 6. Exit criteria for P0-10

- [x] Data map draft (this file).
- [x] Provider checklist template.
- [ ] Provider table filled with verified sources.
- [ ] Contracting entity decided and recorded as an ADR.
