# macOS 配置存在時保留代理頁入口實作計畫

## 1. 先建立失敗回歸測試

- 新增導航測試，驗證有配置檔但沒有代理群組時，`PageLabel.proxies` 仍包含桌面與行動模式。
- 新增反向測試，驗證沒有配置檔時代理頁仍不出現。
- 先執行該測試，確認目前以代理群組判斷的實作會失敗。

## 2. 修改導航條件

- 將 `Navigation.getItems` 的條件名稱改成反映「已有配置檔」的語意。
- 在 `navigationItemsState` 只使用配置檔存在狀態決定代理頁入口，移除初始化前後不同的判斷。
- 不修改核心取得代理群組、訂閱解析或空狀態資料來源。

## 3. 驗證

- 執行新增的導航回歸測試，確認綠燈。
- 執行 Flutter 測試、`flutter analyze --no-fatal-infos`、格式檢查、`git diff --check`。
- 檢查變更差異與工作區，提交修復。

## 4. 跨平台 CI 與下游 issue

- 推送修復提交，等待同一提交的 Android、macOS、Windows、Linux、Dart 測試與總 CI 閘門全部成功。
- CI 全綠後才建立下游 `SingLinkNetwork/FlClash` 的上游 #2294 對應 issue，附上根因、提交與 CI 證據。
- 關閉下游 issue，記錄 macOS 實機可驗證範圍與「核心/訂閱仍無節點時需另追」的限制。
