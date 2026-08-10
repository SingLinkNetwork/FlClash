# macOS Upstream Issue #2281 and Tray Performance Implementation Plan

> **Required subskill:** Use `test-driven-development` for every production-code change and `verification-before-completion` before any issue is marked resolved.

## Goal

Resolve the evidence-supported macOS tray CPU path, investigate the macOS 12 Intel SQLite startup failure without speculative dependency upgrades, and leave a reproducible cross-platform validation workflow for Windows, Linux, Android, and macOS.

## Architecture

- Keep the existing Flutter/Drift architecture and user-visible behavior.
- Put the tray-title decision in a pure Dart unit so it can be tested without a desktop runner.
- Keep native tray changes isolated from Dart behavior changes.
- Treat the final macOS application bundle and its dynamic libraries as the compatibility boundary for SQLite.
- Use CI for compilation and automated tests; use real remote machines or managed QA for platform-specific startup, permissions, tray, and network checks.

## Tech Stack

- Flutter/Dart already pinned by the repository configuration.
- Drift/SQLite and the existing `tray_manager` dependency.
- GitHub Actions or Codemagic for hosted Linux/Windows/macOS jobs.
- A real Intel macOS machine or cloud Mac for macOS 12 compatibility evidence.

## Global Constraints

- Preserve the current app behavior and release target unless a test proves a change is required.
- Do not import the large upstream PR #2271.
- Do not edit generated Dart or platform files by hand when code generation owns them.
- Do not upgrade Drift/SQLite major versions without a verified Flutter/Dart toolchain and full regression evidence.
- Do not claim Windows, Linux, Android, or macOS 12 Intel support is fixed merely because macOS tests pass.
- Keep target issues #1 and #2 open until their remaining platform-specific evidence is recorded.

## Task 1: Add tested tray-title de-duplication

**Files:** `lib/common/tray_title.dart`, `lib/common/tray.dart`, `test/common/tray_title_test.dart`

1. Write failing tests for: first visible title emits once; the same visible title emits nothing; switching to hidden emits an empty title once; repeated hidden calls emit nothing; `reset` allows the next title to emit again.
2. Run the focused Flutter test and record the expected failure before production code exists.
3. Implement a small `TrayTitleCache` with no Flutter or platform dependency.
4. Use it at the existing tray update boundary and reset it when the tray is destroyed.
5. Run the focused test and the existing tray-related tests.
6. Review the diff for unchanged user-facing behavior and commit this isolated change.

## Task 2: Stop unnecessary hidden traffic polling

**Files:** the existing render/action/state provider files and focused provider tests

1. Add failing tests for the polling decision: visible window or enabled tray title keeps the existing update path; hidden window with tray title disabled does not request traffic solely for the tray.
2. Run those tests and record the failure.
3. Implement the smallest guard at the existing timer/provider boundary, preserving proxy state, manual refresh, and visible tray behavior.
4. Run focused provider tests, then `flutter analyze --no-fatal-infos`.
5. Commit only this behavior change.

## Task 3: Validate and stabilize the native tray dependency

1. Inspect the locked `tray_manager` source and compare it with upstream PR #2's fixed commit.
2. Do not consume a mutable PR branch in the release dependency. Use an immutable commit from an owned fork or an auditable vendored copy after confirming the repository's preferred ownership path.
3. Add a small repeatable check that reports the selected tray source and verifies the macOS implementation uses the self-drawn view rather than the high-frequency `NSTextField` path.
4. Build the macOS release bundle and run the check against the resulting source/bundle inputs.
5. Commit the dependency and verification changes separately from Dart logic.

## Task 4: Investigate and minimally fix SQLite startup compatibility

1. Add a database startup smoke test using a temporary database path where the existing test architecture allows it; do not weaken the production migration.
2. Inspect the macOS release bundle, embedded frameworks, linked libraries, and exported symbols for `sqlite3_stmt_isexplain`.
3. If the bundle falls back to the old system SQLite, make the smallest packaging/dependency fix that forces the intended bundled library and add a regression check.
4. If the issue cannot be reproduced on the available macOS version, document the evidence gap in target issue #1 rather than calling it fixed.
5. Run the database tests, analyzer, and macOS release build. Commit only evidence-backed changes.

## Task 5: Cross-platform hosted validation and issue handoff

1. Add or repair CI jobs for Flutter tests plus release compilation on Linux, Windows, and macOS; add Android compilation if the existing Android project is healthy.
2. Upload build artifacts and logs so failures can be inspected without the developer machine.
3. For each platform, record separately: compile result, install/start result, UI smoke result, tray result, and privileged network result.
4. Use a real Intel macOS environment for the macOS 12 startup case; use remote Windows/Linux/Android environments for the corresponding platform checks.
5. Comment on target issues #1 and #2 with source issue links, exact commits, test logs, tested platforms, and remaining gaps. Leave them open when a required platform remains unverified.

## Verification Commands

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test --reporter expanded
flutter build macos --release
```

For Windows, Linux, and Android, run the corresponding release build on their hosted runners rather than claiming local verification from macOS.
