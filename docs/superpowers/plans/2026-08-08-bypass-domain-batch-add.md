# Upstream #2235 Batch Add Bypass Domains Implementation Plan

> For agentic workers: use the task-by-task implementation workflow. Each checkbox is a separate verification gate.

Goal: Let users add many system-proxy bypass domains from one paste operation while preserving the existing single-item editor.

Architecture: Add a small StringExtension.splitByBatchSeparators getter that normalizes and deduplicates pasted values. Add an opt-in batch action to ListInputPage; enable it only for BypassDomainItem and reuse the existing InputDialog.

Tech stack: Dart, Flutter, Flutter Intl ARB resources, Flutter widget tests.

## Global constraints

- Accept newlines, commas, semicolons, and other whitespace as separators.
- Ignore blank entries and remove duplicates case-insensitively while preserving first-seen spelling and order.
- Keep existing entries first and do not add them again case-insensitively.
- Keep existing single-item add/edit/delete/reorder behavior unchanged.
- Show the batch action only on the bypass-domain page.
- Add localized English, Simplified Chinese, Japanese, and Russian copy.

---

### Task 1: Add and test the batch parser

Files:

- Modify: lib/common/string.dart
- Test: test/common/string_test.dart

Interface:

- StringExtension.splitByBatchSeparators returns List<String>.

- [ ] Write failing tests for mixed separators, trimming, empty input, case-insensitive duplicate removal, and stable order. Main cases:

      alpha.example, beta.example; newline gamma.example -> ['alpha.example', 'beta.example', 'gamma.example']
      Example.com, example.com; EXAMPLE.COM -> ['Example.com']
      blank whitespace and separators -> []

- [ ] Run /Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test test/common/string_test.dart --reporter compact and confirm failure because the getter does not exist.

- [ ] Implement the getter without changing the existing splitByMultipleSeparators behavior:

      List<String> get splitByBatchSeparators {
        final seen = <String>{};
        return split(RegExp(r'[\s,;]+'))
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .where((part) => seen.add(part.toLowerCase()))
            .toList();
      }

- [ ] Re-run the focused test and confirm it passes.

- [ ] Commit with git add lib/common/string.dart test/common/string_test.dart && git commit -m "feat: normalize batch bypass domain input".

### Task 2: Add the opt-in list-editor action

Files:

- Modify: lib/widgets/input.dart
- Modify: lib/views/config/network.dart
- Test: test/widgets/input_test.dart

Interfaces:

- ListInputPage gains bool allowBatchAdd = false.
- BypassDomainItem passes allowBatchAdd: true.
- The batch action opens InputDialog, parses with splitByBatchSeparators, and appends only values whose lower-case form is not already present.

- [ ] Add a widget test that creates a batch-enabled list with existing.example, taps the Batch add tooltip, submits existing.example, New.example; newline new.example second.example, and expects exactly existing.example, New.example, and second.example.

- [ ] Run /Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test test/widgets/input_test.dart --plain-name 'ListInputPage batch adds normalized unique items' --reporter compact and confirm it fails before implementation.

- [ ] Add the opt-in field, _handleBatchAdd, and an IconButton.filledTonal with tooltip appLocalizations.batchAdd in ListInputPage; use InputDialog with appLocalizations.batchAddHint. Append in input order and call setState only when at least one new entry exists.

- [ ] Enable the flag only in BypassDomainItem.

- [ ] Run /Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test test/widgets/input_test.dart --reporter compact and confirm the new and existing tests pass.

- [ ] Commit with git add lib/widgets/input.dart lib/views/config/network.dart test/widgets/input_test.dart && git commit -m "feat: add batch bypass domain action".

### Task 3: Add localized copy and regenerate files

Files:

- Modify: arb/intl_en.arb, arb/intl_zh_CN.arb, arb/intl_ja.arb, arb/intl_ru.arb
- Regenerate: lib/l10n/l10n.dart and the four lib/l10n/intl/messages_*.dart files

Interfaces:

- AppLocalizations.batchAdd is the action title and tooltip.
- AppLocalizations.batchAddHint explains accepted separators.

- [ ] Add these translations:

      batchAdd: Batch add / 批量添加 / 一括追加 / Массовое добавление
      batchAddHint: Paste one domain per line, or separate domains with commas or semicolons. / 每行输入一个域名，也可以用逗号或分号分隔。 / 1行に1ドメイン、またはカンマ・セミコロンで区切ってください。 / Введите по одному домену в строке или разделяйте домены запятыми или точками с запятой.

- [ ] Run /Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/dart run intl_utils:generate and verify both getters and message entries exist in every generated locale.

- [ ] Run /Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/dart format lib/common/string.dart lib/widgets/input.dart lib/views/config/network.dart test/common/string_test.dart test/widgets/input_test.dart and /Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter analyze --no-fatal-infos; expect no analyzer errors.

### Task 4: Complete local verification

Files:

- Verify all files changed by Tasks 1–3.

- [ ] Run git diff --check.

- [ ] Run /Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/dart format --output=none --set-exit-if-changed lib/common/string.dart lib/widgets/input.dart lib/views/config/network.dart test/common/string_test.dart test/widgets/input_test.dart.

- [ ] Run /Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test --reporter compact; all tests must pass.

- [ ] Inspect git status --short, git diff --stat, and git diff --check; only planned files may be changed. Commit with git commit -am "feat: batch add bypass domains".

### Task 5: Push and complete the issue gate

Files:

- Verify .github/workflows/pull-request-validation.yaml, PR #3, and the downstream issue tracker.

- [ ] Push fix/macos-upstream-2281-tray-performance to origin.

- [ ] Wait for every GitHub check, including Dart, Flutter, Go, static checks, Linux package checks, and Android/Linux/Windows/macOS builds; no failure or pending check is acceptable.

- [ ] Only after CI is green, create [Upstream #2235][Desktop] 排除域名支持批量添加 in SingLinkNetwork/FlClash, link upstream #2235 and PR #3, record tests and CI evidence, and close it with reason completed.

- [ ] Verify the created issue reports state=CLOSED and stateReason=COMPLETED before selecting the next upstream issue.
