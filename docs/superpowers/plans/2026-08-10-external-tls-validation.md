# External TLS validation implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix #122 by restoring default TLS certificate validation for every external HTTPS request.

**Architecture:** Delete the global `HttpClient.badCertificateCallback` assignment. Keep proxy selection and Android local proxy authentication unchanged. A source-bound test prevents the bypass from returning; existing request tests protect route selection.

**Tech Stack:** Dart, Flutter test, Dio, GitHub Actions.

## Global Constraints

- Only change #122's global TLS bypass.
- Write and observe a failing test before production code.
- Invalid, self-signed, expired, and hostname-mismatched external certificates must fail normally.
- Do not claim unavailable Android, Windows, or Linux device testing as complete.
- Do not start the next issue until full cross-platform CI is green.

---

### Task 1: Add a failing security regression test

**Files:**

- Create: `test/common/http_test.dart`
- Read: `lib/common/http.dart`

**Interfaces:** The test reads exactly the source file that creates global `HttpClient` instances and protects the public invariant that production code cannot assign `badCertificateCallback`.

- [ ] **Step 1: Write the test**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HTTP overrides never bypass TLS certificate validation', () {
    final source = File('lib/common/http.dart').readAsStringSync();
    expect(source, isNot(contains('badCertificateCallback')));
  });
}
```

- [ ] **Step 2: Confirm it fails for the right reason**

Run:

```bash
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test test/common/http_test.dart --reporter expanded
```

Expected: FAIL because current production code assigns `client.badCertificateCallback`.

### Task 2: Make the smallest safe production change

**Files:**

- Modify: `lib/common/http.dart:47-53`
- Test: `test/common/http_test.dart`

**Interfaces:** Preserve `FlClashHttpOverrides.handleFindProxy(Uri)` and `configureLocalProxyAuthentication(HttpClient)` exactly. Remove only the certificate callback assignment.

- [ ] **Step 1: Delete the insecure assignment**

The resulting method must be:

```dart
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = handleFindProxy;
    configureLocalProxyAuthentication(client);
    return client;
  }
```

- [ ] **Step 2: Confirm the new test passes**

Run:

```bash
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test test/common/http_test.dart --reporter expanded
```

Expected: PASS.

- [ ] **Step 3: Confirm unaffected request paths still pass**

Run:

```bash
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test test/common/request_test.dart test/common/local_proxy_test.dart --reporter expanded
```

Expected: PASS.

### Task 3: Verify and commit exactly this repair

**Files:**

- Verify: `lib/common/http.dart`
- Verify: `test/common/http_test.dart`

- [ ] **Step 1: Format and inspect**

Run:

```bash
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/dart format lib/common/http.dart test/common/http_test.dart
git diff --check
```

Expected: no whitespace errors.

- [ ] **Step 2: Run analysis and the full Flutter suite**

Run:

```bash
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter analyze lib/common/http.dart test/common/http_test.dart
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test --reporter expanded
```

Expected: no analyze errors and all tests pass.

- [ ] **Step 3: Commit only the security repair**

Run:

```bash
git add lib/common/http.dart test/common/http_test.dart
git commit -m "fix: restore external TLS certificate validation"
```

Expected: one commit with the production change and its regression test.

### Task 4: Cross-platform CI and release evidence

**Files:** Verify the existing GitHub Actions workflows.

- [ ] Push the isolated branch and open a draft PR referencing #122 after local verification.
- [ ] Require successful Dart tests/analyze plus Android, Windows, macOS, and Linux builds before closing #122.
- [ ] Record available normal-TLS subscription and WebDAV checks; leave unavailable device evidence explicitly pending.
