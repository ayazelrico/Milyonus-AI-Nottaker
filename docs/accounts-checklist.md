# Account readiness checklist

Private repository checklist containing readiness only. No credentials or personal account details.

- [x] Private GitHub repository exists and read access is verified.
- [ ] GitHub branch protection is enabled and verified. GitHub returned HTTP 403 for this private
  repository on the current account plan after CI checks passed on 2026-10-03.
- [ ] Stable Apple development signing identity is selected.
- [ ] Apple Developer Program and distribution team ownership are confirmed.
- [x] Dedicated Supabase development project and Frankfurt (`eu-central-1`) region are approved.
- [x] Supabase Magic Link and the native development callback redirect are approved.
- [ ] Apple and Google Supabase Auth provider credentials and production redirects are approved.
- [ ] Backend hosting and development deployment budget are approved.
- [ ] Anthropic organization and data-use terms are verified.
- [ ] Deepgram and alternative STT accounts are ready for evaluation.
- [ ] Embedding provider EN/TR quality and terms are verified.
- [ ] Stripe entity/account ownership is confirmed before billing implementation.
- [ ] Sentry scrubbing and opt-in diagnostics are configured before collection.
- [ ] Calendar OAuth ownership and permissions are approved before integration.

The selected integration order and the exact credential surface are documented in
`docs/integrations-plan.md`. The owner should provision accounts in that order and place values
only in ignored `backend/.env.local` or the CI secret store.

The runtime loads secrets by environment variable name. Agents never request keys in chat.
