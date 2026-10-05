# 14 - Security, privacy, and legal boundaries

Reconstructed engineering requirements, not a legal opinion or a claim of compliance.

- Provider API keys stay in backend/.env.local or CI secret stores. Empty .env.example values only.
- Never read or print secret files during agent work. Runtime may load its own configured secrets.
- Access/refresh credentials use Keychain once sign-in exists. No token in UserDefaults or logs.
- Backend auth verifies signature, issuer, audience, expiry, subject, and authenticated role.
- Disable raw request logging. Do not log transcripts, audio, prompts, tokens, or provider errors
  that may echo content. Return generic errors and log only allowlisted metadata.
- All future exposed database tables require RLS and cross-workspace isolation tests. User-editable
  metadata cannot authorize access. A service-role credential is server-only.
- Ask for meeting consent before capturing either channel or minting a paid STT token. OS permission
  is a separate requirement. Revocation must stop capture and close streams.
- `POST /v1/stt/token` currently requires an authenticated caller and an exact positive consent
  assertion. It does not yet persist or independently verify meeting consent. P1-13 must add native
  consent and meeting linkage before live capture acceptance.
- Treat transcripts, uploaded docs, and fetched pages as untrusted data. They cannot override system
  prompts or authorize tools. Prompt injection and grounding evaluations are release gates.
- Real recordings and transcript fixtures never enter the repository. Use synthetic fixtures.
- Define cache/buffer lifetime, encryption, deletion, and export before persisting real content.
- Do not promise ZDR, training exclusion, legal compliance, or screen-share invisibility without
  provider contracts and tested product behavior.

## Phase 0 data map

The sample app holds synthetic meeting data in memory and language preferences locally. When account
configuration is present, it can authenticate a user through Supabase and store the session only in
Keychain. Settings can display and explicitly request microphone, screen-capture, and notification
authorization, but granting those permissions does not start capture. The app does not capture audio,
upload meeting content, or call AI. The backend processes JWTs only when a caller invokes protected
endpoints. The dedicated Supabase development project contains an RLS-protected schema. A real auth
acceptance user or an OS permission grant must not be treated as meeting consent or consent to store
meeting or transcript content.

## Before real user data

Confirm contracting entity, subprocessors/regions, DPA and retention terms, breach response, consent
copy, deletion/export behavior, and provider training/ZDR terms. Owner and appropriate legal review
must resolve these items before any production claims or launch.

The P1-07 entitlement checker is an allow-all stub after authentication. Billing-backed authorization,
usage limits, and abuse controls remain mandatory before paid STT is exposed publicly.
