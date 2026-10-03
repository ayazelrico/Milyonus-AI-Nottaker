# 16 - Testing and QA

Foundation checks are in scripts/check.sh and .github/workflows/ci.yml.

## Foundation acceptance

- Swift builds with warnings treated as errors and Swift 6 concurrency checking.
- Shared tests cover data invariants, lifecycle authorization, failures, and localization fallback.
- DesignSystem tests cover token/state behavior; a native UI inspection checks actual layout.
- Generated catalogs are deterministic and --check detects drift.
- Backend tests exercise valid/expired/wrong issuer/wrong audience/bad signature tokens, missing
  configuration, health access, protected endpoints, and non-sensitive errors.
- SwiftLint, SwiftFormat, TypeScript build, ESLint, and formatter checks pass.
- Packaged app resource smoke test passes. Debug Gallery is excluded from release.
- Git checks exclude secrets and build output. CI scans committed history with redacted Gitleaks.

## Later phase acceptance

Use synthetic/licensed EN/TR replay fixtures. Test permissions on the signed app, audio drift and
backpressure, reconnect/cancellation, tenant isolation, deletion/export, and prompt evals. Complete
30-minute capture soaks and macOS 14 compatibility on an actual supported machine before beta.

Record exact commands/results and distinguish local results, remote CI, manual UI inspection,
unavailable test environments, and deferred external setup. A green sample shell is not an audio,
privacy, billing, or production-readiness certification.
