# P0-01 - Repository foundation

Status: implementation authorized by the owner on 2026-10-02.

## Goal and requirements

Bootstrap the existing private repository without losing supplied assets. Restore actionable planning documents and reproducible local checks. Covers NFR-03 reproducibility and NFR-04 safe delivery.

## Plan

1. Initialize main for the Phase 0 bootstrap, retain supplied source assets, and add ignore/editor/lint configuration.
2. Reconstruct missing PRD, architecture, decisions, area rules, setup, security, and roadmap references. Mark account and legal decisions unresolved where no safe default exists.
3. Add PR/issue templates, security reporting guidance, Dependabot, and CI checks.
4. Validate all applicable foundation checks, commit focused changes, and push to the authorized private GitHub repository.

## Acceptance and risks

No secrets, caches, build output, or transcript/audio recordings are tracked. Branch protection is complete only when enabled and verified on GitHub; unsupported account-plan features remain explicitly pending. Future feature work uses branches. Existing source design is used only for visual reference.
