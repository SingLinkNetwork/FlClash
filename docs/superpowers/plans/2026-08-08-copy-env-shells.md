# 複製環境變數 Shell 子選單 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 處理上游 #2195，讓桌面托盤能複製 Bash、Fish、Zsh、PowerShell 四種正確的代理環境變數指令。

**Architecture:** 將指令格式化放在獨立的純 Dart 模組，Shell 類型由列舉限制，托盤只建立子選單並把選擇傳給既有剪貼簿流程。加入專項測試和 Ruby 靜態驗證，讓本機與 GitHub Actions 都能在沒有實體 Windows/Linux 裝置的情況下驗證核心行為與接線。

**Tech Stack:** Flutter/Dart 3.10+, `tray_manager` 的 `MenuItem.submenu`, Flutter test, Ruby 靜態驗證, GitHub Actions。

## Global Constraints

- 只處理桌面托盤與指令產生，不修改 Android 行為、代理核心、訂閱或系統代理狀態。
- 只支援 Bash、Fish、Zsh、PowerShell 四種 Shell，不自動猜測使用者 Shell，不新增 CMD。
- 代理環境變數名稱維持 `all_proxy`，URL 固定由 `http://127.0.0.1:<port>` 產生。
- Linux 保留 Wayland/X11 原生剪貼簿優先與 Flutter 剪貼簿回退。
- 每次程式變更都必須先通過本機測試，再推送並等待 GitHub 全部檢查成功，才處理下一個上游問題。

---

### Task 1: 建立 Shell 指令產生器的失敗測試

**Files:**
- Create: `test/common/proxy_environment_test.dart`
- Modify: `test/common/linux_clipboard_test.dart`

**Interfaces:**
- Consumes: `ProxyEnvironmentShell` and `buildProxyEnvironmentShellCommand` from `lib/common/proxy_environment.dart` (not yet implemented).
- Produces: Four exact command expectations used by Task 2 and the existing Linux clipboard regression test.

- [ ] **Step 1: Write the failing tests**

Create `test/common/proxy_environment_test.dart`:

```dart
import 'package:fl_clash/common/proxy_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildProxyEnvironmentShellCommand', () {
    test('formats Bash and Zsh exports', () {
      expect(
        buildProxyEnvironmentShellCommand(
          shell: ProxyEnvironmentShell.bash,
          port: 7890,
        ),
        'export all_proxy=http://127.0.0.1:7890',
      );
      expect(
        buildProxyEnvironmentShellCommand(
          shell: ProxyEnvironmentShell.zsh,
          port: 1080,
        ),
        'export all_proxy=http://127.0.0.1:1080',
      );
    });

    test('formats Fish global export', () {
      expect(
        buildProxyEnvironmentShellCommand(
          shell: ProxyEnvironmentShell.fish,
          port: 7891,
        ),
        'set -gx all_proxy http://127.0.0.1:7891',
      );
    });

    test('formats PowerShell environment assignment', () {
      expect(
        buildProxyEnvironmentShellCommand(
          shell: ProxyEnvironmentShell.powershell,
          port: 7892,
        ),
        "\$env:all_proxy = 'http://127.0.0.1:7892'",
      );
    });

    test('exposes stable menu labels for every supported shell', () {
      expect(
        ProxyEnvironmentShell.values.map((shell) => shell.label).toList(),
        ['Bash', 'Fish', 'Zsh', 'PowerShell'],
      );
    });
  });
}
```

Update the existing platform-format assertions in `test/common/linux_clipboard_test.dart` to import `proxy_environment.dart` and call `buildProxyEnvironmentShellCommand`; the Windows expectation must be the valid PowerShell assignment above, while the non-Windows expectation remains the Bash export.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test test/common/proxy_environment_test.dart test/common/linux_clipboard_test.dart --reporter expanded
```

Expected: FAIL during compilation because `lib/common/proxy_environment.dart` and its public types/functions do not yet exist.

- [ ] **Step 3: Commit the failing-test checkpoint**

```bash
git add test/common/proxy_environment_test.dart test/common/linux_clipboard_test.dart
git commit -m "test: define shell environment command expectations"
```

### Task 2: Implement the pure Shell command module

**Files:**
- Create: `lib/common/proxy_environment.dart`
- Modify: `lib/common/common.dart`
- Modify: `lib/common/linux_clipboard.dart`

**Interfaces:**
- Consumes: The failing expectations from Task 1.
- Produces: `enum ProxyEnvironmentShell`, `.label`, and `buildProxyEnvironmentShellCommand({required ProxyEnvironmentShell shell, required int port})`.

- [ ] **Step 1: Write the minimal implementation**

Create `lib/common/proxy_environment.dart`:

```dart
enum ProxyEnvironmentShell { bash, fish, zsh, powershell }

extension ProxyEnvironmentShellPresentation on ProxyEnvironmentShell {
  String get label => switch (this) {
    ProxyEnvironmentShell.bash => 'Bash',
    ProxyEnvironmentShell.fish => 'Fish',
    ProxyEnvironmentShell.zsh => 'Zsh',
    ProxyEnvironmentShell.powershell => 'PowerShell',
  };
}

String buildProxyEnvironmentShellCommand({
  required ProxyEnvironmentShell shell,
  required int port,
}) {
  final url = 'http://127.0.0.1:$port';
  return switch (shell) {
    ProxyEnvironmentShell.bash || ProxyEnvironmentShell.zsh =>
      'export all_proxy=$url',
    ProxyEnvironmentShell.fish => 'set -gx all_proxy $url',
    ProxyEnvironmentShell.powershell =>
      '\$env:all_proxy = \'$url\'',
  };
}
```

Export the module from `lib/common/common.dart`. Remove the old boolean Windows/non-Windows command formatter from `lib/common/linux_clipboard.dart`; the Linux clipboard implementation must only contain clipboard discovery and execution.

- [ ] **Step 2: Run the focused tests**

Run the Task 1 command again. Expected: all proxy-environment and Linux clipboard tests pass.

- [ ] **Step 3: Commit the pure-module checkpoint**

```bash
git add lib/common/proxy_environment.dart lib/common/common.dart lib/common/linux_clipboard.dart test/common/proxy_environment_test.dart test/common/linux_clipboard_test.dart
git commit -m "feat: add shell-specific proxy environment commands"
```

### Task 3: Add the tray submenu and focused menu test

**Files:**
- Modify: `lib/common/tray.dart`
- Modify: `test/common/tray_test.dart`

**Interfaces:**
- Consumes: `ProxyEnvironmentShell`, `.label`, and `buildProxyEnvironmentShellCommand` from Task 2.
- Produces: `buildProxyEnvironmentMenuItems({required void Function(ProxyEnvironmentShell) onCopy})`, used by the tray and testable without creating a native tray.

- [ ] **Step 1: Add the menu construction test**

Example test:

Add a test to `test/common/tray_test.dart` that calls `buildProxyEnvironmentMenuItems` with a synchronous recorder and asserts four items, labels `Bash`, `Fish`, `Zsh`, `PowerShell`, and each item has type `normal`.

- [ ] **Step 2: Run the new test to verify it fails**

Run:

```bash
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test test/common/tray_test.dart --reporter expanded
```

Expected: FAIL during compilation because `buildProxyEnvironmentMenuItems` is not defined.

- [ ] **Step 3: Implement menu construction and copy routing**

In `lib/common/tray.dart` add:

```dart
List<MenuItem> buildProxyEnvironmentMenuItems({
  required void Function(ProxyEnvironmentShell shell) onCopy,
}) {
  return [
    for (final shell in ProxyEnvironmentShell.values)
      MenuItem(
        label: shell.label,
        onClick: (_) => onCopy(shell),
      ),
  ];
}
```

Replace the single `copyEnvVarMenuItem` with `MenuItem.submenu`, whose submenu is built from this helper. Change `_copyEnv` to receive a `ProxyEnvironmentShell`, produce the command with `buildProxyEnvironmentShellCommand`, and retain the existing Linux native clipboard then Flutter clipboard fallback.

- [ ] **Step 4: Run the focused tray tests**

Run the Task 3 command again. Expected: all tray tests pass.

- [ ] **Step 5: Commit the tray checkpoint**

```bash
git add lib/common/tray.dart test/common/tray_test.dart
git commit -m "feat: add shell environment tray submenu"
```

### Task 4: Add independent static and CI verification

**Files:**
- Create: `tool/verify_proxy_environment_menu.rb`
- Modify: `.github/workflows/pull-request-validation.yaml`
- Modify: `tool/verify_ci_layout.rb`

**Interfaces:**
- Consumes: Task 2 command module, Task 3 tray helper, focused tests.
- Produces: One static matrix check and one independent focused Flutter test job.

- [ ] **Step 1: Write the static verifier**

Create `tool/verify_proxy_environment_menu.rb` with this exact source:
```ruby
#!/usr/bin/env ruby

root = File.expand_path('..', __dir__)
environment_source = File.read(File.join(root, 'lib', 'common', 'proxy_environment.dart'))
tray_source = File.read(File.join(root, 'lib', 'common', 'tray.dart'))
test_source = File.read(File.join(root, 'test', 'common', 'proxy_environment_test.dart'))
tray_test_source = File.read(File.join(root, 'test', 'common', 'tray_test.dart'))
workflow_source = File.read(
  File.join(root, '.github', 'workflows', 'pull-request-validation.yaml'),
)

%w[bash fish zsh powershell].each do |shell|
  abort "Shell enum is missing: #{shell}" unless
    environment_source.include?("ProxyEnvironmentShell.#{shell}")
end

[
  'export all_proxy=$url',
  'set -gx all_proxy $url',
  %q{'\$env:all_proxy = \'$url\''},
  'buildProxyEnvironmentShellCommand',
].each do |fragment|
  abort "Proxy environment command wiring is missing: #{fragment}" unless
    environment_source.include?(fragment)
end

[
  'MenuItem.submenu',
  'buildProxyEnvironmentMenuItems',
  'buildProxyEnvironmentShellCommand',
  'ProxyEnvironmentShell.values',
].each do |fragment|
  abort "Tray shell submenu wiring is missing: #{fragment}" unless
    tray_source.include?(fragment)
end

abort 'Proxy environment focused tests are missing' unless
  test_source.include?('ProxyEnvironmentShell.powershell') &&
  tray_test_source.include?('buildProxyEnvironmentMenuItems')
abort 'Proxy environment CI job is missing' unless
  workflow_source.include?('proxy-environment:') &&
  workflow_source.include?('flutter test test/common/proxy_environment_test.dart test/common/tray_test.dart --reporter expanded')
abort 'Proxy environment static CI check is missing' unless
  workflow_source.include?('id: proxy-environment-menu') &&
  workflow_source.include?('script: tool/verify_proxy_environment_menu.rb')

puts 'Proxy environment menu wiring verified'
```

- [ ] **Step 2: Run the verifier to verify its wiring test fails**

Run `ruby tool/verify_proxy_environment_menu.rb`. Expected: FAIL because the tray submenu and workflow entry are not yet wired.

- [ ] **Step 3: Wire the CI checks**

Add the static matrix item:

```yaml
- id: proxy-environment-menu
  script: tool/verify_proxy_environment_menu.rb
```

Add an independent `proxy-environment` job on `ubuntu-latest` that checks out the repository, installs Flutter 3.44.8, runs `flutter pub get`, then runs:

The exact job is:
```yaml
proxy-environment:
  name: Proxy environment menu
  runs-on: ubuntu-latest
  steps:
    - name: Checkout
      uses: actions/checkout@v4
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        channel: stable
        flutter-version: ${{ env.FLUTTER_VERSION }}
        cache: true
    - name: Install dependencies
      run: flutter pub get
    - name: Test proxy environment commands and tray menu
      run: flutter test test/common/proxy_environment_test.dart test/common/tray_test.dart --reporter expanded
```

```yaml
flutter test test/common/proxy_environment_test.dart test/common/tray_test.dart --reporter expanded
```

Update `tool/verify_ci_layout.rb` so the new verifier and new job are required by the workflow layout check.
The verifier must add `proxy-environment` to `required_jobs` and `tool/verify_proxy_environment_menu.rb` to `expected_scripts`.

- [ ] **Step 4: Run static and layout checks**

Run:

```bash
ruby tool/verify_proxy_environment_menu.rb
ruby tool/verify_ci_layout.rb
```

Expected: both pass, with the CI layout count increased by one independent static check.

- [ ] **Step 5: Commit the CI checkpoint**

```bash
git add .github/workflows/pull-request-validation.yaml tool/verify_proxy_environment_menu.rb tool/verify_ci_layout.rb
git commit -m "test: verify shell environment menu in CI"
```

### Task 5: Run complete local verification and publish

**Files:** No additional source files; verify all changes from Tasks 1–4.

- [ ] **Step 1: Format and test all Dart changes**

Run:

```bash
DART_BIN=/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/dart ruby tool/verify_dart_format.rb
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter analyze --no-fatal-infos
git diff --check
```

Expected: formatter and diff checks pass, all Flutter tests pass, and analysis exits 0 with no new errors.

- [ ] **Step 2: Push the branch**

```bash
git push origin fix/macos-upstream-2281-tray-performance
```

- [ ] **Step 3: Wait for every GitHub check**

Use the Actions run for the pushed commit. Do not proceed while any job is queued or running, and do not proceed if any job fails. Verify the PR rollup has the exact pushed SHA and every check is successful.

- [ ] **Step 4: Record and close the downstream issue**

Create `[Upstream #2195][Desktop] 托盤複製環境變數增加 Shell 子選單` in `SingLinkNetwork/FlClash` with the upstream link, implementation summary, commit, local results, CI run, and the limitation that no physical Windows/Linux device was used. Close it with reason `completed` only after the complete CI run is green.
Example test:
```dart
test('builds one copy item for each supported shell', () {
  final copied = <ProxyEnvironmentShell>[];
  final items = buildProxyEnvironmentMenuItems(onCopy: copied.add);

  expect(items, hasLength(4));
  expect(items.map((item) => item.label).toList(), [
    'Bash',
    'Fish',
    'Zsh',
    'PowerShell',
  ]);
  expect(items.every((item) => item.type == 'normal'), isTrue);

  items[2].onClick!(items[2]);
  expect(copied, [ProxyEnvironmentShell.zsh]);
});
```
