# Android 本機代理安全修復設計

## 背景

上游 issue [#2183](https://github.com/chen08209/FlClash/issues/2183) 回報 Android 版本的本機代理入口可能被其他 App 直接連線。外部安全分析指出，若本機 SOCKS5/HTTP 入口沒有驗證，其他 App 可以繞過 FlClash 的 VPN 分流規則，直接使用本機代理並取得代理出口 IP。這不是 macOS 本機可以完整重現的問題，必須用程式碼審計、跨平台編譯與 Android 實機測試共同驗收。

目前程式有兩個獨立風險：

1. Android 產生的核心設定沒有固定加入 `authentication`，所以預設 mixed-port 的 TCP 入口可能不要求帳號密碼。
2. 核心的 mixed-port 和 socks-port 會另外建立未驗證的 UDP SOCKS 入口；即使 TCP 加上驗證，UDP 仍可能被其他 App 使用。

另外，Android `VpnService` 以 `ProxyInfo.buildDirectProxy` 設定系統 HTTP 代理，但 Android 這個 API 沒有提供帳號密碼欄位，因此不能安全地把它指向需要驗證的本機代理。

## 目標與不變事項

### 目標

- Android 每次 App 啟動產生新的本機代理密碼，不把密碼寫入使用者設定或日誌。
- Android 產生的核心設定只使用這組隨機帳密，覆蓋匯入設定或腳本遺留的本機代理帳密。
- Android mixed-port 與 socks-port 的 TCP HTTP/SOCKS 入口要求帳密。
- Android 預設 mixed-port 與 socks-port 不再開放未驗證 UDP 入口。
- FlClash 自己的 Dart 網路請求自動回應本機代理的 HTTP Basic 驗證。
- Android 不再設定無法攜帶帳密的系統 HTTP 代理；VPN TUN 仍是 Android 的主要流量路徑。
- 桌面版現有本機代理行為保持不變。
- CI 增加可重複的 Dart/Go 單元測試、Android 靜態安全檢查，以及既有的完整跨平台建置矩陣。

### 不在本次範圍

- 不修改外部控制器、使用者自訂 inbound、遠端代理伺服器或桌面版系統代理。
- 不宣稱已完成 Android 實機安全測試；本機只有 macOS，Android 實機或雲端裝置測試另列為發佈前驗收項目。
- 不移除設定模型中的 `systemProxy` 欄位，避免破壞已存在的 Android 分享檔與 IPC 格式；Android 端只將它視為不再啟用的舊相容欄位。

## 採用方案

採用「Android 隨機帳密 + 核心停用預設 UDP + 關閉 Android 無法驗證的系統代理」方案。

### 方案流程

```text
App 啟動
  -> GlobalState 產生本次程序專用帳密
  -> Android 取得 profile / 執行腳本後
  -> 覆蓋 rawConfig.authentication
  -> 核心啟動
       -> TCP mixed/socks 使用 authStore.Default
       -> Android + 已驗證時不建立預設 UDP listener
  -> App 內部 HttpClient 收到 407
       -> 僅對 localhost:本次 mixed-port 回應 Basic 帳密
  -> Android VPN 不設定 ProxyInfo 系統 HTTP 代理
```

帳號固定為 `flclash-android`，密碼由 `Random.secure()` 產生 32 個 URL-safe 字元。固定帳號方便核心和 Dart 端配對，隨機密碼避免其他 App 依賴固定憑證。密碼只存在於當前 App 程序記憶體，App 重啟即輪換。

### 為什麼不只綁定 localhost

本機 loopback 不是安全邊界：同一台 Android 裝置上的其他 App 通常仍能連線到 `127.0.0.1`。因此只綁定 loopback 不能解決 issue #2183，必須要求驗證。

### 為什麼 Android UDP 直接關閉

目前預設 UDP listener 是獨立的 SOCKS5 UDP 封包入口，不走同一套 TCP HTTP/SOCKS 帳密握手。為了避免「TCP 有驗證但 UDP 仍可繞過」的假安全，Android 有核心帳密時不建立這兩個預設 UDP listener。VPN TUN 的 UDP 流量不受此變更影響。

### 為什麼停用 Android 系統代理

`ProxyInfo` 可以指定本機位址與埠，但沒有可供 FlClash 寫入帳號密碼的欄位。若保留這條路徑，其他 App 會拿到一個無法安全驗證的系統代理入口。Android VPN 已經負責主要流量接管，因此本次直接移除 `VpnService` 的 `setHttpProxy` 路徑，並在 Dart 端不再把 `systemProxy` 傳成有效值；桌面版 `SystemProxyItem` 不變。

## 受影響檔案與責任

- `lib/common/local_proxy.dart`：純 Dart 的本機帳密、設定注入與 Android 系統代理判斷。
- `lib/common/common.dart`：匯出本機代理安全 helper。
- `lib/state.dart`：保存當前程序的隨機帳密。
- `lib/providers/action.dart`：在腳本處理完成後，把 Android 帳密注入最終 profile。
- `lib/providers/state.dart`：Android 的 `VpnOptions.systemProxy` 強制為 false。
- `lib/common/http.dart`、`lib/common/request.dart`：只對本機 mixed-port 回應 HTTP Basic proxy challenge。
- `lib/views/config/network.dart`、`lib/views/dashboard/widgets/quick_options.dart`：不再在 Android 顯示無法安全工作的系統代理開關。
- `android/service/src/main/java/com/follow/clash/service/VpnService.kt`：移除無帳密 `ProxyInfo` 系統代理設定。
- `core/Clash.Meta/listener/listener.go`：Android 且有核心驗證時，跳過預設 SOCKS UDP listener。
- `test/common/local_proxy_test.dart`：Dart helper 的行為回歸測試。
- `core/Clash.Meta/listener/listener_security_test.go`：Go 的 Android/驗證組合測試。
- `tool/verify_android_local_proxy_security.rb`：靜態檢查安全關鍵 wiring。
- `.github/workflows/pull-request-validation.yaml`、`tool/verify_ci_layout.rb`：將靜態檢查納入 required CI。

## 驗收標準

### 功能與安全

- [ ] Android 最終 YAML 含有唯一一組 `authentication`，值為本次程序產生的帳密。
- [ ] Android 匯入設定原本的 `authentication` 和腳本改寫結果都不會覆蓋這組帳密。
- [ ] Android mixed-port / socks-port 的 TCP HTTP 和 SOCKS 入口使用核心驗證。
- [ ] Android 有核心驗證時，`ReCreateMixed` 和 `ReCreateSocks` 都不建立預設 UDP listener，且從有 UDP 切換到驗證狀態時會關閉舊 listener。
- [ ] App 內部 HTTP client 只在 host 為 `localhost`/`127.0.0.1` 且埠等於目前 mixed-port、scheme 為 Basic 時加入帳密。
- [ ] 非本機、非 Basic 或其他埠的 proxy challenge 不會收到 FlClash 帳密。
- [ ] Android `VpnService` 不再呼叫 `setHttpProxy` 或建立 `ProxyInfo`。
- [ ] 桌面版不注入 Android `authentication`，桌面版系統代理仍可正常工作。

### 驗證層級

- Dart targeted test：helper 的密碼格式、設定覆蓋、系統代理判斷與 endpoint 判斷。
- Go targeted test：Android/驗證四種組合的 UDP 決策。
- Ruby static verifier：檢查跨 Dart、Kotlin、Go 的安全 wiring 沒被漏接。
- GitHub Actions：Dart format、analyze、Flutter tests、Go tests/vet、Android/Windows/macOS/Linux 建置與既有 CI gate 全部成功。
- Android 實機或雲端裝置：發佈前由具備裝置的環境驗證「其他 App 無帳密不能使用本機 TCP 代理、UDP 埠不在 listen、VPN 仍可上網」。本次沒有把這項不可取得的實機證據冒充為 CI 已完成。

## 風險與回滾

- 使用者若依賴 Android 系統 HTTP 代理欄位，升級後該欄位不再生效；這是為了避免未驗證代理入口，VPN TUN 路徑不受影響。
- 依賴本機代理的 App 若無法提供帳密，Android 端預設 mixed-port 連線會被拒絕；這正是安全邊界的預期結果。
- 若核心版本在某個平台未正確帶入 Android build tag，CI 的 Android 建置與靜態檢查必須阻止合併；不以 macOS 本機編譯替代。
- 回滾只需回滾本次 commit，不修改使用者既有 profile 資料；程序內密碼不落盤。
