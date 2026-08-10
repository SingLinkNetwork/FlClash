# Android TV Clipboard Paste Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a focusable, localized clipboard-paste action to the reusable URL input dialog so Android TV users can insert subscription links with a remote control.

**Architecture:** Keep the change inside `InputDialog` in `lib/widgets/input.dart`, which is already used by the add-profile URL flow. The action reads `Clipboard.kTextPlain`, replaces the controller value only when non-empty, and leaves validation/submission untouched. Widget tests mock the Flutter platform clipboard channel; no native platform code or new dependency is needed.

**Tech Stack:** Flutter/Dart, `flutter_test`, Flutter `Clipboard` platform channel, existing localization and Material widgets.

## Global Constraints

- Do not add Android permissions or native Android code.
- Do not change URL validation, profile creation, subscription fetching, or clipboard contents.
- Empty or missing clipboard text must preserve the current field value.
- Do not close downstream issue #2196 until local verification and all five CI jobs pass for the exact fix commit.

---

### Task 1: Prove the clipboard behavior with widget tests

**Files:**
- Modify: `test/widgets/input_test.dart`

**Interfaces:**
- Consumes: `InputDialog`, `SystemChannels.platform`, and the existing `_TestApp` test harness.
- Produces: Two regression tests that fail until the paste button and handler exist.

- [ ] **Step 1: Write the failing successful-paste test**

Add `import 'package:flutter/services.dart';` and a widget test that installs a mock `Clipboard.getData` response, pumps `InputDialog`, activates key `ValueKey('input-dialog-paste')`, and expects the text field to contain the copied URL:

```
testWidgets('InputDialog pastes plain clipboard text', (tester) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') {
      return <String, dynamic>{'text': 'https://tv.example/sub.yaml'};
    }
    return null;
  });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  await tester.pumpWidget(
    const ProviderScope(
      child: _TestApp(
        child: Scaffold(
          body: InputDialog(
            title: 'Import URL',
            value: '',
            labelText: 'URL',
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.byKey(const ValueKey('input-dialog-paste')));
  await tester.pump();

  expect(
    tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
    'https://tv.example/sub.yaml',
  );
});
```

- [ ] **Step 2: Write the failing empty-clipboard test**

Add a second widget test using the same mock channel but returning `<String, dynamic>{'text': ''}`. Start the dialog with `value: 'https://existing.example'`, activate the same key, pump once, and assert the controller still contains `https://existing.example`.

- [ ] **Step 3: Run the focused tests and verify the failure is meaningful**

Run:

```
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test test/widgets/input_test.dart --plain-name 'InputDialog'
```

Expected result: the tests fail because `find.byKey(const ValueKey('input-dialog-paste'))` finds no widget. Do not proceed if they pass or fail for an unrelated harness error.

- [ ] **Step 4: Commit the red tests**

```
git add test/widgets/input_test.dart
git commit -m "test: cover Android TV clipboard paste"
```

### Task 2: Add the minimal reusable paste action

**Files:**
- Modify: `lib/widgets/input.dart:129-212`

**Interfaces:**
- Consumes: the existing `_InputDialogState._textController` and `AppLocalizations.paste`.
- Produces: a `ValueKey('input-dialog-paste')` button and `_pasteFromClipboard()` behavior used by every `InputDialog` consumer.

- [ ] **Step 1: Implement the clipboard handler**

Inside `_InputDialogState`, add:

```
Future<void> _pasteFromClipboard() async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text;
  if (!mounted || text == null || text.isEmpty) {
    return;
  }
  _textController.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
}
```

- [ ] **Step 2: Add the localized focusable button**

In the existing `InputDecoration` for the dialog's `TextFormField`, add:

```
suffixIcon: IconButton(
  key: const ValueKey('input-dialog-paste'),
  tooltip: appLocalizations.paste,
  onPressed: _pasteFromClipboard,
  icon: const Icon(Icons.content_paste),
),
```

Keep the existing controller, validator, `onFieldSubmitted`, and dialog actions unchanged.

- [ ] **Step 3: Format and run the focused tests**

Run:

```
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/dart format lib/widgets/input.dart test/widgets/input_test.dart
git diff --check
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test test/widgets/input_test.dart --plain-name 'InputDialog'
```

Expected result: both InputDialog tests pass.

- [ ] **Step 4: Run the full local regression suite and analyzer**

Run sequentially:

```
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter analyze
```

Expected result: all tests pass; analyzer exits successfully with only the repository's pre-existing `withOpacity` informational messages.

- [ ] **Step 5: Commit the implementation**

```
git add lib/widgets/input.dart test/widgets/input_test.dart
git commit -m "fix: add clipboard paste action to URL inputs"
```

### Task 3: Cross-platform CI and downstream issue record

**Files:**
- No source files beyond Tasks 1–2.
- External: downstream issue `SingLinkNetwork/FlClash#48` for upstream #2196.

**Interfaces:**
- Consumes: the exact implementation commit and local test evidence from Task 2.
- Produces: a pushed branch, a green five-platform CI run, a fully documented and closed issue #48.

- [ ] **Step 1: Push the fix branch**

```
git push origin fix/macos-upstream-2281-tray-performance
```

- [ ] **Step 2: Verify the exact GitHub Actions run**

Run:

```
gh run list --repo SingLinkNetwork/FlClash --branch fix/macos-upstream-2281-tray-performance --limit 1
ACTION_ID=$(gh run list --repo SingLinkNetwork/FlClash --branch fix/macos-upstream-2281-tray-performance --limit 1 --json databaseId --jq '.[0].databaseId')
gh run view "$ACTION_ID" --repo SingLinkNetwork/FlClash --json status,conclusion,headSha,jobs
```

The run is acceptable only when `status` is `completed`, `conclusion` is `success`, `headSha` equals the pushed commit, and Dart, Linux, Android, macOS, and Windows jobs all report `success`.

- [ ] **Step 3: Create the downstream issue with source and evidence**

Create issue #48 only if no existing downstream issue references upstream #2196. Include the upstream URL, the confirmed missing remote-friendly paste action, the exact commit, local test count, analyzer result, CI URL/SHA, and the limitation that physical Android TV remote testing was not available.

- [ ] **Step 4: Verify the issue body and close only after evidence is present**

Read the created issue and comment back the same evidence. Confirm the body and comment are intact, then close with reason `completed`. Verify the final state is `CLOSED`.

- [ ] **Step 5: Confirm repository cleanliness**

```
git status --short --branch
git show --stat --oneline HEAD
```

Expected result: the fix branch is clean and points to the CI-verified commit.
