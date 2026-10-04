# P1-05 - Core Audio process tap spike

Status: completed on 2026-10-04. ScreenCaptureKit remains the Phase 1 system-audio baseline.

## Goal

Compare the macOS 14.2 Core Audio process tap path with the implemented ScreenCaptureKit path and
decide whether Phase 1 should replace, supplement, or defer it. Base the decision on Apple APIs,
the repository's macOS 14 deployment target, lifecycle complexity, filtering, synchronization,
permissions, and measurable product needs.

## Plan

1. Inspect the installed Apple SDK declarations for `CATapDescription`, process tap creation, tap
   destruction, aggregate-device composition, and sub-tap drift compensation.
2. Cross-check the API flow and permission requirements against Apple's Core Audio documentation.
3. Compare that flow with the existing audio-only ScreenCaptureKit source and the shared audio
   frame contract.
4. Record facts separately from engineering inferences. Do not assume lower latency or better
   reliability without a controlled device test.
5. Update ADR-004 with the decision, constraints, and objective reconsideration triggers.

## Boundaries

- This spike does not add a second production capture implementation.
- It does not raise the macOS 14 deployment target or weaken the ScreenCaptureKit fallback.
- It does not request new permissions, create persistent aggregate devices, or introduce a virtual
  audio driver.
- It does not claim performance improvements without measurements on supported hardware.

## Acceptance

- The report covers availability, filtering, permissions, clocking, lifecycle, failure modes, and
  migration cost.
- ADR-004 states the selected baseline and the conditions that can reopen the decision.
- Any future experiment is availability-gated and has explicit cleanup and evaluation criteria.
- Repository checks and CI pass.
