# Windows MSIXBundle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Windows-native MSIX build target and a verified x64+ARM64 `.msixbundle` artifact for upstream issue #2209.

**Architecture:** Keep existing EXE/ZIP packaging unchanged. Extend the repository-owned `setup.dart` CLI with a Windows-only `msix` path that builds the current host architecture, then use Windows SDK `MakeAppx.exe` in a separate CI job to bundle the two native MSIX files. Use a PowerShell verifier to inspect the nested manifests, plus a Ruby workflow verifier and Dart command-contract tests.

**Tech Stack:** Dart, Flutter 3.44.8, the `msix` Dart package, Windows SDK `MakeAppx.exe`, PowerShell, Ruby/Minitest, GitHub Actions.

## Global Constraints

- The existing EXE/ZIP path and all non-Windows targets must remain unchanged.
- `msix` artifacts in Pull Request CI are unsigned; no production certificate or private key may be committed or exposed.
- A bundle must contain exactly one `x64` and one `arm64` package with matching identity, version, and publisher.
- The Windows ARM64 build must run on `windows-11-arm`; do not label an x64 artifact as ARM64.
- Each issue is completed only after local verification and the complete GitHub Pull Request check rollup is green.

---

### Task 1: Define the MSIX CLI contract with failing tests

**Files:**
- Modify: `test/setup_test.dart`
- Test: `test/setup_test.dart`

**Interfaces:**
- Produces `setup.windowsMsixArchitecture(String)` returning `x64` for `amd64`/`x64` and `arm64` for `arm64`.
- Produces `setup.createWindowsMsixBuildArgs({required bool verbose})` returning the direct Flutter release build argument list.
- Produces `setup.createMsixCreateArgs({required String architecture, required String outputDirectory})` returning an unsigned MSIX command argument list with fixed FlClash identity metadata.

- [ ] **Step 1: Write the failing tests**

Add tests that assert:

```dart
test('maps supported Windows host architectures to MSIX values', () {
  expect(setup.windowsMsixArchitecture('amd64'), 'x64');
  expect(setup.windowsMsixArchitecture('x64'), 'x64');
  expect(setup.windowsMsixArchitecture('ARM64'), 'arm64');
});

test('rejects unsupported Windows host architectures', () {
  expect(
    () => setup.windowsMsixArchitecture('ia32'),
    throwsA(isA<ArgumentError>()),
  );
});

test('creates release Windows build arguments from env.json', () {
  expect(setup.createWindowsMsixBuildArgs(verbose: false), [
    'build',
    'windows',
    '--release',
    '--dart-define-from-file=env.json',
  ]);
});

test('creates unsigned MSIX arguments with shared identity metadata', () {
  final args = setup.createMsixCreateArgs(
    architecture: 'arm64',
    outputDirectory: r'C:\workspace\dist',
  );

  expect(args, containsAllInOrder([
    'run',
    'msix:create',
    '--release',
    '--build-windows',
    'false',
    '--architecture',
    'arm64',
    '--output-path',
    r'C:\workspace\dist',
    '--identity-name',
    'com.singlinknetwork.flclash',
    '--publisher',
    'CN=SingLinkNetwork',
    '--sign-msix',
    'false',
  ]));
});
```

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```bash
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test test/setup_test.dart --reporter expanded
```

Expected: compilation fails because the three new setup helpers do not exist.

- [ ] **Step 3: Commit the red test**

```bash
git add test/setup_test.dart
git commit -m "test: define Windows MSIX CLI contract"
```

### Task 2: Implement the architecture-specific MSIX CLI path

**Files:**
- Modify: `pubspec.yaml`
- Modify: `setup.dart`
- Test: `test/setup_test.dart`

**Interfaces:**
- `setup.dart` accepts `msix` as a custom Windows target without changing the default `exe,zip` target list.
- `dart setup.dart windows --targets msix` prepares `env.json`, builds the current host architecture in release mode, and invokes `dart run msix:create` with explicit architecture and unsigned metadata.

- [ ] **Step 1: Add the `msix` dev dependency and CLI helpers**

Add `msix: ^3.18.0` under `dev_dependencies`. Implement the three public test helpers and keep the unsupported architecture error explicit.

- [ ] **Step 2: Route only the Windows `msix` target through the new path**

Before Flutter Distributor activation, detect a single `msix` target on Windows. Run:

```text
flutter build windows --release --dart-define-from-file=env.json
dart run msix:create --release --build-windows false --architecture <x64|arm64> --output-path <root>/dist --output-name FlClash-<x64|arm64> --display-name FlClash --publisher-display-name SingLinkNetwork --identity-name com.singlinknetwork.flclash --publisher CN=SingLinkNetwork --capabilities internetClient --sign-msix false --install-certificate false
```

Return the first non-zero exit code and leave the existing Distributor path untouched for every other target.

- [ ] **Step 3: Run the focused tests to verify green**

Run:

```bash
/Volumes/SING_02/flclash/flutter-sdk-3.44.8/bin/flutter test test/setup_test.dart --reporter expanded
```

Expected: all setup tests pass. A real Windows package build is deferred to the Windows CI job because the local host is macOS.

- [ ] **Step 4: Commit the CLI implementation**

```bash
git add pubspec.yaml pubspec.lock setup.dart test/setup_test.dart
git commit -m "feat: add Windows MSIX setup target"
```

### Task 3: Add the bundle command and structural verifier

**Files:**
- Create: `tool/verify_msix.ps1`
- Create: `tool/bundle_msix.ps1`
- Create: `tool/verify_msixbundle.ps1`
- Create: `tool/verify_msixbundle_pipeline.rb`
- Create: `tool/verify_msixbundle_pipeline_test.rb`

**Interfaces:**
- `bundle_msix.ps1 -X64Package <path> -Arm64Package <path> -OutputPath <path>` creates a clean staging directory and invokes the newest Windows SDK `MakeAppx.exe bundle` command.
- `verify_msix.ps1 -PackagePath <path> -ExpectedArchitecture <x64|arm64>` checks one native package before it enters the bundle.
- `verify_msixbundle.ps1 -BundlePath <path>` fails unless the bundle contains exactly two MSIX files, one x64 and one arm64, with matching FlClash identity metadata and matching `AppxBundleManifest.xml` architecture, version, and file references.
- `verify_msixbundle_pipeline.rb` checks workflow wiring and the presence of both scripts.

- [ ] **Step 1: Write the failing static pipeline test**

Create a Minitest that runs the Ruby verifier against the current repository and expects failure because the new jobs/scripts are absent.

Run:

```bash
ruby tool/verify_msixbundle_pipeline_test.rb
```

Expected: failure identifying missing MSIX bundle CI wiring.

- [ ] **Step 2: Implement the MakeAppx bundler**

Resolve `makeappx.exe` from `PATH` first, then from `Program Files (x86)\Windows Kits\10\bin\*\x64`. Read both package manifests, require the same four-part version, copy only the two supplied `.msix` files into a clean temporary directory, run `MakeAppx.exe bundle /v /bv <shared-version> /d <stage> /p <output>.msixbundle`, and fail on any missing input or non-zero exit code.

- [ ] **Step 3: Implement the single-package PowerShell verifier**

Open one `.msix` as a ZIP and require `AppxManifest.xml`, `AppxBlockMap.xml`, `resources.pri`, and a Windows executable. Parse the manifest with namespace-safe XPath and fail unless the processor architecture matches the requested x64 or arm64 value. Read the executable's PE header and require machine type `0x8664` for x64 or `0xAA64` for ARM64 so a mislabeled binary cannot pass.

- [ ] **Step 4: Implement the PowerShell bundle manifest verifier**

Open the `.msixbundle` as a ZIP, locate the bundle manifest and exactly two nested `.msix` files, open each nested package as a ZIP, parse its manifest with namespace-safe XPath, and compare the required identity fields. Print that the structure is verified and that production signing remains required.

- [ ] **Step 5: Implement the Ruby workflow verifier and its regression test**

Require the `windows-msix` architecture matrix, `windows-msixbundle` dependency, `MakeAppx` command, PowerShell verifier, artifact downloads/uploads, `msix` dependency, static matrix entry, and the final `ci-complete` gate. Add tests that use fake workflow text to ensure missing or fake required elements fail rather than passing silently.

- [ ] **Step 6: Run the Ruby regression test**

Run:

```bash
ruby tool/verify_msixbundle_pipeline_test.rb
```

Expected: the test passes after the verifier is implemented, while the real repository verifier remains red until the workflow is wired in Task 4.

- [ ] **Step 7: Commit the bundle tooling**

```bash
git add tool/verify_msix.ps1 tool/bundle_msix.ps1 tool/verify_msixbundle.ps1 tool/verify_msixbundle_pipeline.rb tool/verify_msixbundle_pipeline_test.rb
git commit -m "feat: add MSIXBundle bundler and verifier"
```

### Task 4: Wire independent x64, ARM64, and bundle CI checks

**Files:**
- Modify: `.github/workflows/pull-request-validation.yaml`
- Modify: `tool/verify_ci_layout.rb`
- Modify: `tool/verify_msixbundle_pipeline.rb`

**Interfaces:**
- `windows-msix` has two visible matrix checks: x64 on `windows-2022`, ARM64 on `windows-11-arm`.
- `windows-msixbundle` depends on both architecture artifacts, runs on `windows-2022`, bundles them, verifies the real output, and uploads `windows-msixbundle`.
- The existing `build` job depends on `windows-msixbundle`.
- `ci-complete` always runs after the build matrix and fails unless that complete rollup succeeds.

- [ ] **Step 1: Add the architecture build matrix**

Install Go, Rust, and dependencies; run the x64 Flutter SDK on both Windows runners; on the ARM64 runner, replace the cached Dart SDK, remove the x64 Flutter tool snapshot so Flutter rebuilds it with ARM64 Dart, and precache the native ARM64 engine; run `dart setup.dart windows --targets msix`; assert exactly one `dist/FlClash-<architecture>.msix`; run `tool/verify_msix.ps1` against the native package; upload it as `windows-msix-<architecture>`.

- [ ] **Step 2: Add the bundle job**

Download both artifacts into separate folders, call `tool/bundle_msix.ps1`, run `tool/verify_msixbundle.ps1`, and upload the resulting `.msixbundle` with `if-no-files-found: error`.

- [ ] **Step 3: Make CI layout verification enforce the new jobs**

Require the new job names, static verifier script, `windows-msixbundle` in the existing build prerequisites, and `ci-complete` as the final required-check gate. Keep the minimum independent static check count at or above its current threshold.

- [ ] **Step 4: Run the static verifier suite locally**

Run:

```bash
ruby tool/verify_msixbundle_pipeline.rb
ruby tool/verify_ci_layout.rb
git diff --check
```

Expected: both verifiers pass and the diff has no whitespace errors.

- [ ] **Step 5: Commit the CI wiring**

```bash
git add .github/workflows/pull-request-validation.yaml tool/verify_ci_layout.rb tool/verify_msixbundle_pipeline.rb
git commit -m "test: verify Windows MSIXBundle in CI"
```

### Task 5: Run local checks and push the issue branch

**Files:**
- Verify all changed files and generated lockfile changes.

- [ ] **Step 1: Run focused and full local tests**

Run the setup test, full Flutter test suite, Flutter analysis, Dart formatting verifier, both MSIX static verifiers, CI layout verifier, and `git diff --check`. Record exit codes and test counts.

- [ ] **Step 2: Inspect the final diff and worktree**

Confirm only #2209 files changed, the branch is clean except for committed work, and no certificates/private keys are present.

- [ ] **Step 3: Push the branch**

Push `fix/macos-upstream-2281-tray-performance` and record the exact head SHA.

### Task 6: Wait for the complete GitHub check rollup

- [ ] **Step 1: Identify the workflow run for the exact head SHA**

Use the GitHub Actions run list and reject stale runs from older commits.

- [ ] **Step 2: Inspect every job**

Require the x64 MSIX job, ARM64 MSIX job, bundle job, all existing static checks, all core tests, Linux package checks, and Android/Linux/Windows/macOS builds to be successful.

- [ ] **Step 3: Diagnose and fix any failure before proceeding**

Do not create the downstream completion record or select the next upstream issue until the exact PR rollup is fully green.

### Task 7: Record issue #2209 and select the next issue

- [ ] **Step 1: Create a downstream issue record**

Document the upstream link, commits, exact CI run, generated artifacts, and the unsigned-production-signing boundary.

- [ ] **Step 2: Close the downstream record as completed**

Only close it after the exact PR rollup is green and the issue statement is complete.

- [ ] **Step 3: Re-triage upstream and choose the next independent issue**

Check for an existing downstream record before selecting the next issue; keep the one-issue-at-a-time rule.
