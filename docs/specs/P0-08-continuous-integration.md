# P0-08 - Continuous integration

Implementation authorized with Phase 0; validation occurs before the task is marked complete.

## Goal and requirements

Run repeatable Swift and backend checks on every pull request and main update. Covers NFR-03 and
NFR-04. A real deployed health route remains dependent on approved hosting and is tracked separately.

## Plan

1. Pin GitHub Actions commits and downloaded Swift tools with checksums.
2. Build/test/lint Swift on macOS and backend on Node LTS with a frozen pnpm lockfile.
3. Check generated resources and packaged debug/release resource smoke tests.
4. Scan committed history with Gitleaks using redacted output.
5. Push verified commits, inspect actual CI results, fix failures, then enable available protection.

## Acceptance and risks

Checks require no provider secrets and never invoke paid AI. CI uses read-only repository permissions.
Both debug and release must build; Gallery is debug-only. Pinning dependencies does not eliminate
supply-chain risk, so dependency updates receive review. Cloud deployment, billing limits, and
private-repository protection capabilities must not be represented as completed before verification.
