# Android Core Patch Delivery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the existing Android local-proxy UDP security fix from the parent repository, without forking Clash.Meta, so local builds and both GitHub workflows compile and test the same patched core.

**Architecture:** Keep `core/Clash.Meta` pinned to the public upstream commit `80362fc1895dcf60b79b562896653046e0687413`. Store the narrow core change as a checked-in patch, apply it idempotently before every Go-core build, and apply it explicitly before CI jobs that inspect or test the submodule directly. The patch itself disables default SOCKS and mixed UDP listeners only in Android builds; Dart-side credentials and Android system-proxy removal already live in commit `3dd64a5`.

**Tech Stack:** Dart command-line utility, Git patches, Go/Clash.Meta, Ruby static verifier, Flutter/GitHub Actions.

## Global Constraints

- Do not fork or push to `chen08209/Clash.Meta`.
- Leave the parent Gitlink at `80362fc1895dcf60b79b562896653046e0687413`; the parent repository must contain all delivery artifacts.
- Patch application must be idempotent: a second run succeeds without changing source; an upstream conflict fails loudly.
- The core patch must run before every native Go-core build on Android, macOS, Linux, and Windows.
- PR CI and tag-release CI must explicitly apply the patch before direct submodule tests or static inspection.
- Do not claim Android device coverage; require successful Android CI build and retain device/cloud testing as release evidence.

---

### Task 1: Red test for parent-owned patch delivery

**Files:**
- Create: `tool/verify_clash_meta_patch_delivery.rb`
- Modify: `tool/verify_android_local_proxy_security.rb`
- Test: `tool/verify_clash_meta_patch_delivery.rb`

**Interfaces:**
- Consumes `tool/patches/0001-android-disable-default-udp-listeners.patch`, `tool/apply_clash_meta_patches.dart`, the build-tool source, and both workflows.
- Produces a CI-safe assertion that fails if the core patch cannot be delivered from this repository.

- [ ] **Step 1: Write the verifier before delivery files exist**

  The verifier must abort unless all of these are true:

  ```ruby
  patch = read.call('tool', 'patches', '0001-android-disable-default-udp-listeners.patch')
  applier = read.call('tool', 'apply_clash_meta_patches.dart')
  build_tool = read.call('plugins', 'setup', 'buildkit', 'build_tool', 'lib', 'src', 'build_tool.dart')
  pr_workflow = read.call('.github', 'workflows', 'pull-request-validation.yaml')
  release_workflow = read.call('.github', 'workflows', 'build.yaml')

  abort 'core patch must pin listener/listener.go' unless patch.include?('diff --git a/listener/listener.go b/listener/listener.go')
  abort 'core patch must include a listener regression test' unless patch.include?('listener_security_test.go')
  abort 'core patch applier is missing' unless applier.include?('0001-android-disable-default-udp-listeners.patch')
  abort 'native build tool does not apply core patches' unless build_tool.include?('applyClashMetaPatches')
  abort 'PR CI does not apply core patch before direct core checks' unless pr_workflow.include?('Apply Clash.Meta patches')
  abort 'release CI does not apply core patch before direct core checks' unless release_workflow.include?('Apply Clash.Meta patches')
  ```

- [ ] **Step 2: Observe the red result**

  Run:

  ```bash
  ruby tool/verify_clash_meta_patch_delivery.rb
  ```

  Expected: exit 1 because the patch file and Dart applier do not exist yet.

- [ ] **Step 3: Add this verifier to the Android security verifier and PR static matrix**

  `tool/verify_android_local_proxy_security.rb` must require the delivery verifier source to exist. Add this exact matrix entry to `static-source`:

  ```yaml
  - id: clash-meta-patch-delivery
    script: tool/verify_clash_meta_patch_delivery.rb
  ```

  Add the script path to `tool/verify_ci_layout.rb`'s expected static scripts.

### Task 2: Store and apply the core patch without a fork

**Files:**
- Create: `tool/patches/0001-android-disable-default-udp-listeners.patch`
- Create: `tool/apply_clash_meta_patches.dart`
- Modify: `plugins/setup/buildkit/build_tool/lib/src/build_tool.dart`

**Interfaces:**
- `Future<void> applyClashMetaPatches(String rootDir)` applies all repository-owned patches to `core/Clash.Meta`.
- `Future<void> runMain(List<String> args)` invokes it once after resolving `_rootDir` and before a platform builder can call `GoBuilder.buildAll`.

- [ ] **Step 1: Add the exact core patch**

  Create the patch from the known, reviewed difference between upstream `80362fc1895dcf60b79b562896653046e0687413` and local security commit `cdbbefab0568f73f6941e7a06c2f532f5eeeabf1`:

  ```bash
  git -C core/Clash.Meta diff --binary --full-index \
    80362fc1895dcf60b79b562896653046e0687413 \
    cdbbefab0568f73f6941e7a06c2f532f5eeeabf1 \
    -- listener/listener.go listener/listener_security_test.go
  ```

  The patch must import `constant/features`, add `shouldDisableDefaultUDP(bool)`, and skip/retire `socks.NewUDP` in both `ReCreateSocks` and `ReCreateMixed` when `features.Android` is true. It must include `TestShouldDisableDefaultUDP`.

- [ ] **Step 2: Implement the portable idempotent applier**

  `tool/apply_clash_meta_patches.dart` uses only `dart:io` and must run these commands in `core/Clash.Meta` for each patch:

  ```dart
  final alreadyApplied = await Process.run(
    'git',
    ['apply', '--reverse', '--check', patch.path],
    workingDirectory: coreDir.path,
  );
  if (alreadyApplied.exitCode == 0) continue;

  final check = await Process.run(
    'git',
    ['apply', '--check', '--whitespace=error-all', patch.path],
    workingDirectory: coreDir.path,
  );
  if (check.exitCode != 0) {
    stderr.write(check.stderr);
    throw ProcessException('git apply', ['--check', patch.path], check.stderr as String, check.exitCode);
  }

  final applied = await Process.run(
    'git',
    ['apply', '--whitespace=error-all', patch.path],
    workingDirectory: coreDir.path,
  );
  if (applied.exitCode != 0) {
    stderr.write(applied.stderr);
    throw ProcessException('git apply', [patch.path], applied.stderr as String, applied.exitCode);
  }
  ```

  `main()` resolves the repository root from the script location, calls the function, and exits nonzero after printing the failure. Patch files are sorted by filename so the mechanism remains deterministic.

- [ ] **Step 3: Call the applier before native Go builds**

  In `build_tool.dart`, import `../../../tool/apply_clash_meta_patches.dart` is not valid because that tool is outside the package. Instead create `lib/src/clash_meta_patches.dart` in the build-tool package with the same `applyClashMetaPatches` implementation, then call it in `runMain` immediately after `_rootDir` is assigned:

  ```dart
  _rootDir = (topResults['root-dir'] as String?) ?? _findProjectRoot();
  await applyClashMetaPatches(_rootDir);
  await runner.run(args);
  ```

  The command-line tool imports that package source through a relative import so CI can invoke the same implementation directly.

- [ ] **Step 4: Prove apply and repeat apply**

  In a clean checkout of `80362fc1895dcf60b79b562896653046e0687413`, run:

  ```bash
  dart tool/apply_clash_meta_patches.dart
  dart tool/apply_clash_meta_patches.dart
  git -C core/Clash.Meta diff --check
  ```

  Expected: both commands exit 0; the second reports the patch already applied.

### Task 3: Validate the patched core directly

**Files:**
- Test: `core/Clash.Meta/listener/listener_security_test.go` (from patch)
- Modify: `.github/workflows/pull-request-validation.yaml`
- Modify: `.github/workflows/build.yaml`

**Interfaces:**
- Direct test command: `go test ./listener -run '^TestShouldDisableDefaultUDP$' -count=1` from `core/Clash.Meta`.

- [ ] **Step 1: Run the Go regression test after patch application**

  ```bash
  (cd core/Clash.Meta && go test ./listener -run '^TestShouldDisableDefaultUDP$' -count=1)
  ```

  Expected: both desktop and Android decision cases pass.

- [ ] **Step 2: Make PR CI apply the patch before direct use**

  For `go-tests`, `go-vet`, and `core-cli-arguments`, add this Ubuntu step immediately after checkout:

  ```yaml
  - name: Apply Clash.Meta patches
    run: dart tool/apply_clash_meta_patches.dart
  ```

  Set up Flutter before this step, because it provides Dart. Add a direct listener test to `go-tests`. For `static-source`, check out `submodules: recursive`, set up Flutter, apply the patch, then run the Ruby matrix. The build matrix remains covered by the build-tool invocation in Task 2.

- [ ] **Step 3: Make tag-release CI apply the patch before direct tests**

  In the `test` job in `.github/workflows/build.yaml`, after Flutter setup and before `go test .`, add the same `Apply Clash.Meta patches` step and run the listener regression test. The release build matrix is covered by the build-tool invocation.

- [ ] **Step 4: Keep the CI structural checks accurate**

  Extend `tool/verify_ci_layout.rb` so it checks that the static-source checkout includes recursive submodules and that `go-tests` contains both the applier and the listener security test. Update `tool/verify_android_local_proxy_security.rb` to require the patch, applier, and the direct Go test command.

### Task 4: Green verification and review gate

**Files:**
- Test: `test/common/local_proxy_test.dart`
- Test: `tool/verify_android_local_proxy_security.rb`
- Test: `tool/verify_clash_meta_patch_delivery.rb`

- [ ] **Step 1: Run the specific security checks**

  ```bash
  ruby tool/verify_clash_meta_patch_delivery.rb
  ruby tool/verify_android_local_proxy_security.rb
  dart tool/apply_clash_meta_patches.dart
  (cd core/Clash.Meta && go test ./listener -run '^TestShouldDisableDefaultUDP$' -count=1)
  ```

- [ ] **Step 2: Run application-level checks using the pinned SDK**

  ```bash
  /Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter pub get
  /Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test test/common/local_proxy_test.dart --reporter expanded
  /Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter analyze --no-fatal-infos
  ruby tool/verify_ci_layout.rb
  git diff --check
  ```

- [ ] **Step 3: Commit only the P0 delivery fix**

  ```bash
  git add tool/patches/0001-android-disable-default-udp-listeners.patch \
    tool/apply_clash_meta_patches.dart \
    plugins/setup/buildkit/build_tool/lib/src/clash_meta_patches.dart \
    plugins/setup/buildkit/build_tool/lib/src/build_tool.dart \
    tool/verify_clash_meta_patch_delivery.rb \
    tool/verify_android_local_proxy_security.rb \
    tool/verify_ci_layout.rb \
    .github/workflows/pull-request-validation.yaml \
    .github/workflows/build.yaml
  git add -f docs/superpowers/plans/2026-08-10-android-local-proxy-core-patch.md
  git commit -m "fix(android): deliver authenticated core patch in CI"
  ```

### Plan self-review

- Scope is limited to making the already-reviewed Android UDP protection reproducible; no desktop proxy behavior changes are introduced.
- The patch itself, native builder, PR workflow, release workflow, direct Go test, and static verifier are all covered.
- No fork, secret, or Android-device claim is required.
- The plan contains no unresolved implementation placeholders.
