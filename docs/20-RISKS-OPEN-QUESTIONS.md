# 20 - Risks and open questions

Reconstructed on 2026-10-02. Unknowns are not silently treated as completed setup.

| Item | Impact | Current decision or next step |
|---|---|---|
| Original specs absent | Cannot claim restoration of historic decisions | Reconstruct explicit requirements and ADRs; retain supplied reference files |
| Full Xcode not installed | Local SwiftLint cannot load SourceKit | SwiftPM build/tests work with Command Line Tools; CI uses full Xcode for SwiftLint; install Xcode when local SwiftLint/signing tools are needed |
| Stable signing identity unknown | TCC persistence cannot be accepted | Ad hoc local preview is labeled; owner selects identity/team |
| SwiftLint local runtime | Binary is installed but needs Xcode SourceKit | Required check runs on GitHub macOS Xcode runner; SwiftFormat runs locally |
| Provider accounts/keys | No real STT/AI smoke tests | Owner configures secret stores; no secrets in chat or Git |
| Hosting and region | Dev deployment pending | Prepare deployable backend; no paid provisioning without approval |
| Dev/staging/prod ambiguity | Accidental environment coupling | Local development now; choose cloud environments before provisioning |
| Supabase Auth integration | Real login acceptance pending | Native PKCE, Keychain, callback, and backend identity code is tested; the development callback is allowlisted, and an owner-controlled email must complete Magic Link acceptance |
| GitHub plan/protection | Private branch protection is unavailable on the current account plan | GitHub returned HTTP 403 on 2026-10-03; retain private visibility and enable protection after a plan upgrade |
| Font redistribution | Bundled OFL assets need notices retained | Inter Tight and Instrument Serif licenses and pinned source are committed; system fallback remains usable |
| EN/TR code switching | Model language support is not bilingual quality | Evaluate fixed EN/TR and code-switching independently in Phase 1 |
| Temporary STT tokens | Token expiry does not close active connections | Session cap, metering, and abuse limits required before paid streaming |
| macOS 14 compatibility | New SDK APIs may leak into code | Availability checks and macOS 14 test machine before beta |
| Legal entity and agreements | Contracts, Apple/Stripe ownership unresolved | Owner decision; no automatic legal default |
| Latency/quality targets | Three-second cards are unmeasured | Measure replay percentiles and relevance before advertising |

Accounts checklist: docs/accounts-checklist.md. Do not include secrets, account numbers, or certificates.
