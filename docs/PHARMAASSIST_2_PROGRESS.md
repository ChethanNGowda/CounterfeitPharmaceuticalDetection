# PharmaAssist 2.0 Implementation Progress

This document records verified work against the PharmaAssist 2.0 development
brief. A feature is marked complete only after its existing integrations and
relevant tests are checked.

## Phase 0: Repository inspection and baseline

- Inspected the repository structure, root and Flutter documentation, Flutter
  dependency manifest, API entry point, application navigation, theme system,
  home, scanner, result, and settings screens.
- Confirmed the checkout is on `main`, tracks the intended GitHub repository,
  and began with one existing local commit ahead of `origin/main`.
- Confirmed current documented limits: offline AI inference is unavailable;
  only the EfficientNet-B0 pharmaceutical checkpoint is present; model
  registration does not imply a trained checkpoint is available.
- Baseline checks: `flutter analyze` passed; `flutter test` passed (83 tests);
  `pytest -q` passed (215 tests).

## Phase 1: Flutter architecture and UI/UX

- In progress.
- Added the missing System appearance option while preserving existing dark and
  light preferences. Existing `system` values are no longer rewritten to dark
  when Settings opens, and the shared palette follows the device brightness
  when System is selected.
- Added a four-page first-run introduction covering visual screening, camera
  guidance, saved reports, offline record keeping, backend requirements, and a
  clear screening disclaimer. Completion is persisted locally and skip is
  available.
- Regression coverage added for theme preservation and onboarding navigation,
  disclaimer, and skip behavior. `flutter analyze` passed; `flutter test`
  passed (85 tests); `git diff --check` passed.

## Later phases

Not started. Existing functionality and documented limitations must be
re-inspected before each phase is implemented; no unsupported model, product
verification source, or prediction capability should be presented as available.
