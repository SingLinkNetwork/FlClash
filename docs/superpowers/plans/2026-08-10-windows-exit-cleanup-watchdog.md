# Windows Exit Cleanup Watchdog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure normal exit cleanup is not interrupted by the old three-second forced termination timer.

**Architecture:** A common helper owns the cancellable watchdog timer. `SystemAction.handleExit` supplies its existing cleanup closure, a ten-second timeout, and the forced-exit logging callback. Its existing final exit remains the only normal completion path.

**Tech Stack:** Dart, Flutter test.

## Global Constraints

- Preserve existing cleanup ordering and platform-specific conditions.
- Do not remove the hard fallback for a hung cleanup.
- Add tests before production code.

---

### Task 1: Testable cleanup watchdog

**Files:**
- Create: `lib/common/exit_cleanup.dart`
- Modify: `lib/common/common.dart`
- Create: `test/common/exit_cleanup_test.dart`

**Interfaces:**
- Produces: `Future<void> runExitCleanupWithWatchdog({required Future<void> Function() cleanup, required Duration timeout, required void Function() onTimeout})`

- [ ] **Step 1: Write failing tests**

```dart
await runExitCleanupWithWatchdog(
  cleanup: () async {},
  timeout: const Duration(milliseconds: 10),
  onTimeout: () => timeoutCalls++,
);
await Future<void>.delayed(const Duration(milliseconds: 20));
expect(timeoutCalls, 0);
```

Also test that an error from `cleanup` cancels the timer, and that an unfinished cleanup invokes `onTimeout` once.

- [ ] **Step 2: Verify tests fail**

Run: `flutter test test/common/exit_cleanup_test.dart`
Expected: compile failure because `runExitCleanupWithWatchdog` does not exist.

- [ ] **Step 3: Implement minimal helper**

```dart
final timer = Timer(timeout, onTimeout);
try {
  await cleanup();
} finally {
  timer.cancel();
}
```

- [ ] **Step 4: Verify tests pass**

Run: `flutter test test/common/exit_cleanup_test.dart`
Expected: PASS.

### Task 2: Use watchdog for application exit

**Files:**
- Modify: `lib/providers/action.dart:675-699`
- Test: `test/common/exit_cleanup_test.dart`

**Interfaces:**
- Consumes: `runExitCleanupWithWatchdog` from Task 1.

- [ ] **Step 1: Replace uncancellable delayed exit**

Wrap the existing `handleExit` cleanup body in `runExitCleanupWithWatchdog` with a ten-second timeout.  Its timeout callback logs a warning through `commonPrint` and calls `system.exit()`.

- [ ] **Step 2: Preserve normal final exit**

Keep the current `finally { system.exit(); }` so successful cleanup and cleanup failures retain the existing application termination behaviour.

- [ ] **Step 3: Verify targeted tests and analysis**

Run: `flutter test test/common/exit_cleanup_test.dart && flutter analyze lib/common/exit_cleanup.dart lib/common/common.dart lib/providers/action.dart test/common/exit_cleanup_test.dart`
Expected: PASS with no diagnostics.

### Task 3: Full regression verification

**Files:**
- No additional files.

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 2: Commit the reviewed change**

Run: `git add -f docs/superpowers/specs/2026-08-10-windows-exit-cleanup-watchdog-design.md docs/superpowers/plans/2026-08-10-windows-exit-cleanup-watchdog.md && git add lib/common/exit_cleanup.dart lib/common/common.dart lib/providers/action.dart test/common/exit_cleanup_test.dart && git commit -m "fix: wait for exit cleanup before forced termination"`
Expected: one focused commit.
