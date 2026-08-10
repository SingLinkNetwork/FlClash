# 外部 HTTPS 憑證驗證修復設計

## 背景

我方追蹤單 [#122](https://github.com/SingLinkNetwork/FlClash/issues/122) 與上游 PR #2204 指出：`FlClashHttpOverrides.createHttpClient` 目前對每個 `HttpClient` 設定 `badCertificateCallback = (_, _, _) => true`。這會接受所有外部 HTTPS 的無效憑證。

全域 override 會被一般 `HttpClient()` 使用；`Request` 建立的預設、proxy 與 direct Dio client 都可能受影響。因此訂閱下載、更新檢查、WebDAV 同步與圖片下載都不應保有這個全域繞過。

## 目標與不變事項

- 外部 HTTPS 一律使用 Dart 正常的 TLS 憑證與主機名稱驗證。
- 保留現有 `findProxy`：核心啟動時外部請求仍可經本機 HTTP proxy，停用或暫停時仍直接連線。
- 保留 Android 本機 HTTP proxy 的 Basic authentication 邏輯。
- 不新增「忽略憑證錯誤」設定或隱藏例外。
- 不修改使用者設定、核心 YAML 或 WebDAV 資料。

## 方案比較與採用方案

1. **完全移除 callback（採用）**：HTTP CONNECT proxy 對外 TLS 驗證的是目的網站，並非本機 proxy；本機控制器也使用 HTTP。因此不需要 TLS 例外，安全邊界最清楚。
2. 僅允許 `localhost`／`127.0.0.1`：比現狀安全，但 callback 實際收到的是 HTTPS 目的主機，這個例外沒有實際需求，且日後可能被誤用。
3. 讓使用者開關略過驗證：方便不正確伺服器，但會重新暴露訂閱與 WebDAV 的中間人風險，不採用。

## 設計

`FlClashHttpOverrides.createHttpClient` 只設定 `findProxy` 與 Android 本機 proxy authentication，不設定 `badCertificateCallback`。Dart 預設行為會在外部憑證無效或主機名稱不符時拒絕連線。

回歸測試會以 `File` 讀取此安全邊界的少量原始碼，明確斷言 production code 不再指派 `badCertificateCallback`；這比替一個未使用 helper 寫測試更能防止日後把全域 bypass 加回去。現有 request tests 則驗證 proxy/direct 選路不變。

## 受影響檔案

- `lib/common/http.dart`：移除全域 callback，保留 proxy 與 Android authentication wiring。
- `test/common/http_test.dart`：先寫「production code 不可指派 callback」的回歸測試，並保留 proxy 路由與 Android authentication 的測試。
- `docs/superpowers/plans/2026-08-10-external-tls-validation.md`：記錄 TDD、CI 與真機驗收步驟。

## 驗收

- `FlClashHttpOverrides` 不再含 `badCertificateCallback` 指派。
- 現有 proxy/direct 路由與 Android proxy authentication 測試持續通過。
- Flutter analyze、完整 Flutter tests，以及 GitHub Actions 的 Android、Windows、macOS、Linux build 都成功。
- 發佈前以正常 TLS 訂閱與 WebDAV 端點驗證 proxy/direct 路徑；無法取得的其他平台真機不以 CI 冒充。

## 風險與回滾

自簽、過期或網域不符的外部 HTTPS 端點會改為失敗；這是安全修復的預期結果，使用者應修正服務端憑證。回滾只需回滾本次單一 commit，無資料遷移或設定變更。
