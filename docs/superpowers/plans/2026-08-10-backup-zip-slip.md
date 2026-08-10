# Backup ZIP Path Traversal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure backup restoration cannot write ZIP entries outside its restore directory.

**Architecture:** Add a small path-validation helper in `task.dart`. Validate the whole decoded archive before opening an output stream, then extract only the returned safe paths. Regression tests exercise the public `restoreBackupArchive` function using real ZIP bytes and temporary files.

**Tech Stack:** Dart, Flutter test, `archive`, `path`.

## Global Constraints

- Keep valid relative backup entries compatible.
- Reject unsafe entries before any archive content is written.
- Preserve input and output stream cleanup on both success and failure.
- Run the focused Dart test before the full Flutter suite and complete CI before merging.

---

### Task 1: Prove unsafe ZIP entries escape today

**Files:**

- Modify: `test/common/task_test.dart`
- Test: `test/common/task_test.dart`

**Interfaces:**

- Consumes: `Future<void> restoreBackupArchive(String backupFilePath, String restoreDirPath)`.
- Produces: regression examples for unsafe and valid ZIP paths.

- [ ] **Step 1: Write failing tests**

Add a test that creates an archive containing `safe.txt` followed by
`../escaped.txt`, calls `restoreBackupArchive`, expects a `FileSystemException`,
and asserts neither `restore/safe.txt` nor the sibling `escaped.txt` exists.
Add a second test with `profiles/nested.yaml` and assert its exact contents are
written beneath the restore directory.

- [ ] **Step 2: Run the focused test to verify the safety case fails**

Run:

```bash
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test test/common/task_test.dart --reporter expanded
```

Expected: the unsafe-path assertion fails because the current implementation
writes the safe entry before it reaches `../escaped.txt`.

### Task 2: Validate all archive paths before extraction

**Files:**

- Modify: `lib/common/task.dart`
- Test: `test/common/task_test.dart`

**Interfaces:**

- Produces: `String resolveRestoreArchiveEntryPath(String restoreDirPath, String entryName)`.
- Consumes: decoded `ArchiveFile.name` values in `restoreBackupArchive`.

- [ ] **Step 1: Implement the minimal validator**

Add a helper that rejects empty names, absolute POSIX names, backslashes,
Windows drive prefixes, `.` and `..` traversal, and any resolved path that is
not strictly inside `absolute(restoreDirPath)`. It throws
`FileSystemException('Invalid backup archive entry', entryName)` for rejection.

- [ ] **Step 2: Validate before writing**

Map every decoded archive file to its validated output path before calling
`Directory(restoreDirPath).create` or constructing an `OutputFileStream`.
Extract only after this mapping succeeds for the whole archive.

- [ ] **Step 3: Run focused tests**

Run:

```bash
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test test/common/task_test.dart --reporter expanded
```

Expected: all backup restore, stream-release, and existing task tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/common/task.dart test/common/task_test.dart
git commit -m "fix: reject path traversal in backup restore"
```

### Task 3: Verify the complete client suite

**Files:**

- Verify only: `lib/common/task.dart`, `test/common/task_test.dart`

- [ ] **Step 1: Format and analyze changed files**

Run:

```bash
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/dart format lib/common/task.dart test/common/task_test.dart
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter analyze lib/common/task.dart test/common/task_test.dart
```

Expected: no formatting changes and no analysis issues.

- [ ] **Step 2: Run full tests**

Run:

```bash
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test --reporter compact
```

Expected: the full suite passes.

- [ ] **Step 3: Review diff safety**

Run:

```bash
git diff --check origin/main...HEAD
```

Expected: no whitespace or conflict-marker errors.
