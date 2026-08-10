# URL Import Route Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give first-time URL imports an explicit proxy/direct route choice while preserving proxy as the default.

**Architecture:** A stateful import dialog returns a value object containing URL and `useProxy`.  The Profiles action receives the choice and forwards it to the existing profile download API.

**Tech Stack:** Flutter, Riverpod action layer, Flutter widget tests.

## Global Constraints

- Proxy is the default for every existing caller.
- Direct import is available only after an explicit user choice.
- Reuse existing localized `syncViaProxy` and `syncDirect` labels.
- Do not alter the direct HTTP client or existing profile-sync menu.

---

### Task 1: Route-aware URL import dialog

**Files:**
- Modify: `lib/views/profiles/add.dart`
- Create: `test/views/profiles/add_test.dart`

- [ ] Write widget tests that assert proxy is selected by default and a direct selection returns `useProxy: false` with the submitted URL.
- [ ] Run the test and confirm it fails before the route-aware dialog exists.
- [ ] Add `URLImportResult` and route radio controls using existing localized labels.
- [ ] Run the focused widget test.

### Task 2: Forward the chosen route to download

**Files:**
- Modify: `lib/providers/action.dart:1086-1100`
- Test: `test/views/profiles/add_test.dart`

- [ ] Extend `addProfileFormURL` with `useProxy = true` and forward it to `Profile.update`.
- [ ] Connect the add-sheet dialog result to that method.
- [ ] Verify format, analysis, focused tests, and full test suite.

### Task 3: Review and CI

- [ ] Run UI self-review in default and direct-selection states; state any rendering limitation honestly.
- [ ] Create a draft PR and require full cross-platform CI before merge.
