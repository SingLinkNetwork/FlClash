# Android 本機代理安全修復 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修復上游 #2183，讓 Android 本機代理具備程序級隨機驗證，並移除無法攜帶帳密的預設 UDP 與系統 HTTP 代理入口。

**Architecture:** Flutter 端在產生最終核心 YAML 前注入當前程序的隨機 `authentication`，並讓 App 內部 HttpClient 只對目前 mixed-port 自動完成 Basic proxy challenge。核心端沿用既有 `authStore.Default` 驗證 TCP；Android 永遠跳過預設 mixed/socks UDP listener，VPN 端不再設定 `ProxyInfo` 系統代理。

**Tech Stack:** Dart/Flutter、Go/Clash.Meta、Kotlin/Android VpnService、Ruby 靜態驗證、GitHub Actions。

## Global Constraints

- 每一個上游 issue 完成後，必須等完整跨平台 CI/CD 全部通過，才可以處理下一個 issue。
- Android 實機不可用時，只報告程式碼、測試與 CI 證據，不宣稱已完成實機驗證。
- 桌面版代理與桌面版系統代理行為不變。
- 不將本次隨機帳密寫入偏好設定、profile、日誌或 issue comment。
- 不移除 `VpnOptions.systemProxy` 欄位，保留分享檔與 IPC 相容性。
- 先寫測試並觀察缺少實作的失敗，再加入最小實作。

---

### Task 1: 保存設計規格與計畫

**Files:**
- Create: `docs/superpowers/specs/2026-08-09-android-local-proxy-security-design.md`
- Create: `docs/superpowers/plans/2026-08-09-android-local-proxy-security.md`

- [x] **Step 1: 固定問題、取捨與驗收標準**

  已在設計規格記錄上游報告、核心現況、採用方案、桌面相容性與 Android 實機限制。

- [ ] **Step 2: 提交規格與計畫**

  Run:

  ```bash
  git add -f docs/superpowers/specs/2026-08-09-android-local-proxy-security-design.md docs/superpowers/plans/2026-08-09-android-local-proxy-security.md
  git commit -m "docs: define Android local proxy security fix"
  ```

  Expected: commit succeeds and only the two design documents are included.

---

### Task 2: 先寫 Dart 本機代理安全測試

**Files:**
- Create: `test/common/local_proxy_test.dart`

**Interfaces:**
- Consumes: planned `LocalProxyCredentials`, `applyAndroidLocalProxyAuthentication`, `shouldUseSystemProxy`, and `isLocalProxyEndpoint` from `lib/common/local_proxy.dart`.
- Produces: executable regression cases for later Flutter implementation.

- [ ] **Step 1: Write the failing test**

  Add tests with these exact behaviors:

  ```dart
  test('generated credentials are safe for core authentication', () {
    final credentials = LocalProxyCredentials.generate();
    expect(credentials.username, 'flclash-android');
    expect(credentials.password.length, 32);
    expect(credentials.password, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    expect(credentials.coreAuthentication, 'flclash-android:${credentials.password}');
  });

  test('Android authentication replaces imported authentication without mutating input', () {
    final credentials = const LocalProxyCredentials(
      username: 'flclash-android',
      password: 'test-password',
    );
    final rawConfig = <String, dynamic>{
      'authentication': ['old-user:old-password'],
      'mixed-port': 7890,
    };

    final patched = applyAndroidLocalProxyAuthentication(
      rawConfig: rawConfig,
      credentials: credentials,
    );

    expect(patched['authentication'], ['flclash-android:test-password']);
    expect(rawConfig['authentication'], ['old-user:old-password']);
    expect(patched['mixed-port'], 7890);
  });

  test('only Android disables the unsupported system proxy path', () {
    expect(shouldUseSystemProxy(isAndroid: true, requested: true), isFalse);
    expect(shouldUseSystemProxy(isAndroid: true, requested: false), isFalse);
    expect(shouldUseSystemProxy(isAndroid: false, requested: true), isTrue);
    expect(shouldUseSystemProxy(isAndroid: false, requested: false), isFalse);
  });

  test('proxy credentials are limited to the current local endpoint', () {
    expect(isLocalProxyEndpoint('localhost', 7890, 7890), isTrue);
    expect(isLocalProxyEndpoint('127.0.0.1', 7890, 7890), isTrue);
    expect(isLocalProxyEndpoint('10.0.0.2', 7890, 7890), isFalse);
    expect(isLocalProxyEndpoint('localhost', 7891, 7890), isFalse);
  });
  ```

- [ ] **Step 2: Run test to verify it fails**

  Run:

  ```bash
  flutter test test/common/local_proxy_test.dart --reporter expanded
  ```

  Expected on a Flutter-equipped runner: FAIL because `lib/common/local_proxy.dart` and its functions do not exist yet. On this macOS workspace, if `flutter` is unavailable, record the exact command-not-found limitation and let GitHub CI perform the Flutter red test/green test gate.

---

### Task 3: 先寫 Go Android UDP 決策測試

**Files:**
- Create: `core/Clash.Meta/listener/listener_security_test.go`

**Interfaces:**
- Consumes: planned `shouldDisableDefaultUDP(androidBuild bool) bool` in package `listener`.
- Produces: a Go regression test covering desktop and Android builds.

- [ ] **Step 1: Write the failing test**

  Add:

  ```go
  func TestShouldDisableDefaultUDP(t *testing.T) {
      tests := []struct {
          name         string
          androidBuild bool
          want         bool
      }{
          {name: "desktop", androidBuild: false, want: false},
          {name: "android", androidBuild: true, want: true},
      }

      for _, test := range tests {
          t.Run(test.name, func(t *testing.T) {
              if got := shouldDisableDefaultUDP(test.androidBuild); got != test.want {
                  t.Fatalf("shouldDisableDefaultUDP(%t) = %t, want %t", test.androidBuild, got, test.want)
              }
          })
      }
  }
  ```

- [ ] **Step 2: Run test to verify it fails**

  Run from `core/Clash.Meta`:

  ```bash
  go test ./listener -run TestShouldDisableDefaultUDP -count=1
  ```

  Expected: FAIL because `shouldDisableDefaultUDP` does not exist yet.

---

### Task 4: Implement Dart credentials and inject them into Android profiles

**Files:**
- Create: `lib/common/local_proxy.dart`
- Modify: `lib/common/common.dart`
- Modify: `lib/state.dart`
- Modify: `lib/providers/action.dart`

**Interfaces:**
- Produces `LocalProxyCredentials.generate()`, `LocalProxyCredentials.coreAuthentication`, `applyAndroidLocalProxyAuthentication(...)`, `shouldUseSystemProxy(...)`, and `isLocalProxyEndpoint(...)`.

- [ ] **Step 1: Add the smallest pure helper implementation**

  `LocalProxyCredentials.generate()` must choose 32 characters from `A-Za-z0-9_-` using `Random.secure()`. `applyAndroidLocalProxyAuthentication` must clone the top-level map and replace only `authentication` with a one-element list containing `coreAuthentication`. `shouldUseSystemProxy` must return `requested && !isAndroid`. `isLocalProxyEndpoint` must accept only `localhost` or `127.0.0.1` and an exact expected port.

- [ ] **Step 2: Store credentials for the current process**

  Add a `final localProxyCredentials = LocalProxyCredentials.generate();` field to `GlobalState`. Do not persist it or print it.

- [ ] **Step 3: Inject authentication after scripts have run**

  In `getProfile`, immediately after the optional `handleEvaluate` call and before `MakeRealProfileState`, use:

  ```dart
  if (system.isAndroid) {
    rawConfig = applyAndroidLocalProxyAuthentication(
      rawConfig: rawConfig,
      credentials: globalState.localProxyCredentials,
    );
  }
  ```

- [ ] **Step 4: Run the Dart targeted test**

  Run:

  ```bash
  flutter test test/common/local_proxy_test.dart --reporter expanded
  ```

  Expected: all four tests pass.

- [ ] **Step 5: Commit**

  ```bash
  git add lib/common/local_proxy.dart lib/common/common.dart lib/state.dart lib/providers/action.dart test/common/local_proxy_test.dart
  git commit -m "fix(android): add per-process local proxy authentication"
  ```

---

### Task 5: Authenticate FlClash's own Dart proxy requests

**Files:**
- Modify: `lib/common/http.dart`
- Modify: `lib/common/request.dart`

**Interfaces:**
- Consumes: `globalState.localProxyCredentials`, `isLocalProxyEndpoint`, and the current `patchClashConfigProvider` mixed port.
- Produces: an `HttpClient.authenticateProxy` callback that only supplies the generated Basic credentials to the current local mixed-port.

- [ ] **Step 1: Configure global HttpClient instances**

  Add a helper that, on Android only, sets `authenticateProxy`. It must reject a non-local host, a port different from the current mixed-port, or a non-Basic scheme. For an accepted challenge it must call `addProxyCredentials` with `HttpClientBasicCredentials` and return `true`.

- [ ] **Step 2: Configure the custom Dio proxy client**

  Call the same helper in `Request._createProxiedDio` after creating its `HttpClient`. Do not call it for the direct Dio client.

- [ ] **Step 3: Run targeted Dart tests and format check**

  Run:

  ```bash
  flutter test test/common/local_proxy_test.dart --reporter expanded
  dart format --output=none --set-exit-if-changed lib/common/local_proxy.dart lib/common/http.dart lib/common/request.dart lib/providers/action.dart lib/providers/state.dart lib/state.dart test/common/local_proxy_test.dart
  ```

  Expected: tests pass and formatter exits 0. If Flutter/Dart is absent locally, record it and rely on the matching CI jobs.

- [ ] **Step 4: Commit**

  ```bash
  git add lib/common/http.dart lib/common/request.dart
  git commit -m "fix(android): authenticate internal proxy requests"
  ```

---

### Task 6: Disable Android's unauthenticated system proxy path in Flutter and Kotlin

**Files:**
- Modify: `lib/providers/state.dart`
- Modify: `lib/views/config/network.dart`
- Modify: `lib/views/dashboard/widgets/quick_options.dart`
- Modify: `android/service/src/main/java/com/follow/clash/service/VpnService.kt`

**Interfaces:**
- Consumes: `shouldUseSystemProxy`.
- Produces: Android `VpnOptions.systemProxy == false`, no Android system proxy UI, and no `ProxyInfo`/`setHttpProxy` call in the service.

- [ ] **Step 1: Force the effective Android option off**

  In `sharedState`, replace `systemProxy: vpnSetting.systemProxy` with:

  ```dart
  systemProxy: shouldUseSystemProxy(
    isAndroid: system.isAndroid,
    requested: vpnSetting.systemProxy,
  ),
  ```

- [ ] **Step 2: Remove Android-only UI entries**

  Keep desktop `SystemProxyItem` unchanged. Do not include `VpnSystemProxyItem` in the Android network list or the Android VPN quick-options list; the stored legacy setting may remain for compatibility but cannot be activated.

- [ ] **Step 3: Remove the unsafe Android service operation**

  Remove the `ProxyInfo` import and the `Build.VERSION...setHttpProxy(...)` block from `VpnService.kt`. Keep VPN route establishment and `Core.startTun` unchanged.

- [ ] **Step 4: Run static checks**

  Run:

  ```bash
  ruby tool/verify_android_local_proxy_security.rb
  git diff --check
  ```

  Expected: static verifier passes after Task 8 adds it; until then, use source inspection to confirm the intended wiring.

- [ ] **Step 5: Commit**

  ```bash
  git add lib/providers/state.dart lib/views/config/network.dart lib/views/dashboard/widgets/quick_options.dart android/service/src/main/java/com/follow/clash/service/VpnService.kt
  git commit -m "fix(android): remove unauthenticated system proxy"
  ```

---

### Task 7: Implement core Android UDP protection

**Files:**
- Modify: `core/Clash.Meta/listener/listener.go`
- Test: `core/Clash.Meta/listener/listener_security_test.go`

**Interfaces:**
- Consumes: failing `shouldDisableDefaultUDP` test.
- Produces: Android-aware UDP listener lifecycle for `ReCreateSocks` and `ReCreateMixed`.

- [ ] **Step 1: Add the decision helper**

  Import `constant/features` and `listener/auth`, then add:

  ```go
  func shouldDisableDefaultUDP(androidBuild bool, authenticated bool) bool {
      return androidBuild && authenticated
  }

  func defaultUDPDisabled() bool {
      return shouldDisableDefaultUDP(features.Android, authStore.Default.Authenticator() != nil)
  }
  ```

- [ ] **Step 2: Update `ReCreateSocks`**

  Calculate `disableUDP := defaultUDPDisabled()`. Close an existing `socksUDPListener` when `disableUDP` is true. Return early when the TCP listener is already correct and either UDP is already correct or UDP is disabled. Create the TCP listener only when missing, and create `socks.NewUDP` only when `disableUDP` is false and the UDP listener is missing. `defaultUDPDisabled()` must be true for every Android build, even if the current config has no `authentication` entry.

- [ ] **Step 3: Update `ReCreateMixed`**

  Apply the same lifecycle rules to `mixedUDPLister` and `mixed.New`. The existing mixed TCP listener must continue using `authStore.Default`; the independent default UDP listener is skipped on every Android build.

- [ ] **Step 4: Run Go targeted test and formatting**

  From `core/Clash.Meta` run:

  ```bash
  gofmt -w listener/listener.go listener/listener_security_test.go
  go test ./listener -run TestShouldDisableDefaultUDP -count=1
  ```

  Expected: test passes.

- [ ] **Step 5: Commit**

  ```bash
  git add core/Clash.Meta/listener/listener.go core/Clash.Meta/listener/listener_security_test.go
  git commit -m "fix(android): disable unauthenticated default UDP listeners"
  ```

---

### Task 8: Add static security verifier and wire it into CI

**Files:**
- Create: `tool/verify_android_local_proxy_security.rb`
- Modify: `.github/workflows/pull-request-validation.yaml`
- Modify: `tool/verify_ci_layout.rb`

**Interfaces:**
- Consumes: the Dart, Kotlin, Go, and test files from Tasks 2–7.
- Produces: one independent required `static-source` job that fails if a security-critical wiring point disappears.

- [ ] **Step 1: Write the verifier**

  The Ruby verifier must read the relevant files and abort unless all of these are present: Android profile authentication injection, proxy challenge handling with `addProxyCredentials` and `HttpClientBasicCredentials`, Android system-proxy gating, no `ProxyInfo`/`setHttpProxy` in `VpnService.kt`, `shouldDisableDefaultUDP` plus conditional `socks.NewUDP` in core, and the Dart/Go regression test files.

- [ ] **Step 2: Add the verifier to the static-source matrix**

  Add:

  ```yaml
  - id: android-local-proxy-security
    script: tool/verify_android_local_proxy_security.rb
  ```

  to `.github/workflows/pull-request-validation.yaml`.

- [ ] **Step 3: Make the CI layout verifier require it**

  Add `tool/verify_android_local_proxy_security.rb` to `expected_scripts` in `tool/verify_ci_layout.rb`.

- [ ] **Step 4: Run local static checks**

  ```bash
  ruby tool/verify_android_local_proxy_security.rb
  ruby tool/verify_ci_layout.rb
  git diff --check
  ```

  Expected: both Ruby verifiers pass and the diff has no whitespace errors.

- [ ] **Step 5: Commit**

  ```bash
  git add -f tool/verify_android_local_proxy_security.rb .github/workflows/pull-request-validation.yaml tool/verify_ci_layout.rb
  git commit -m "ci: verify Android local proxy security wiring"
  ```

---

### Task 9: Run the full issue gate and close downstream #85

**Files:**
- No source changes unless verification finds a failure.

- [ ] **Step 1: Inspect the final diff and source wiring**

  ```bash
  git diff main...HEAD --stat
  git diff --check
  git status --short --branch
  ```

  Expected: only the documented #2183 files are changed; no credentials appear in tracked files.

- [ ] **Step 2: Push the branch**

  ```bash
  git push origin fix/macos-upstream-2281-tray-performance
  ```

- [ ] **Step 3: Wait for the exact pushed commit's full workflow**

  Use GitHub Actions for `pull-request-validation.yaml`. Verify the run `headSha` equals the pushed commit, every matrix job has conclusion `success`, and `ci-complete` is successful. Do not use an older green run.

- [ ] **Step 4: If CI fails, debug and rerun before issue closure**

  Read the failing job log, apply the smallest fix, rerun the relevant local check, push a new commit, and repeat the full workflow verification. Do not close #85 on partial success.

- [ ] **Step 5: Record exact evidence on downstream issue #85**

  Comment the exact commit SHA, exact Actions run URL, total successful job count, and the honest Android-device limitation. Do not include the generated username/password.

- [ ] **Step 6: Close #85 only after evidence is verified**

  Close `https://github.com/SingLinkNetwork/FlClash/issues/85`, then read it back and verify `state == CLOSED` and the evidence comment is present.

- [ ] **Step 7: Pause this round**

  Report the upstream issue, downstream issue, commit, full CI run, what was verified, and the Android real-device limitation. Do not start the next upstream issue in the same round.
