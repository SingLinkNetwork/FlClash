# Windows 便攜版資料路徑

## 來源

- 上游問題：[chen08209/FlClash#2244](https://github.com/chen08209/FlClash/issues/2244)
- 需求：Windows 便攜版不應把設定與快取留在 `AppData\\Local\\com.follow` 或 `AppData\\Roaming\\com.follow`，重裝系統或從 USB 移動時仍應保留在程式目錄內。

## 驗收規則

1. Windows 執行檔所在目錄可寫入時，應將持久資料放到執行檔旁的 `data` 目錄，將快取放到執行檔旁的 `cache` 目錄。
2. Windows 執行檔所在目錄不可寫入時，必須繼續使用 `path_provider` 提供的系統資料與快取目錄，避免安裝在受保護目錄的程式啟動失敗。
3. macOS、Linux、Android 的既有資料路徑不變。
4. 可寫入判斷不能留下測試檔案；路徑檢查失敗要安全回退。
5. 新增單元測試覆蓋可寫入便攜路徑、不可寫入回退、非 Windows 不啟用便攜路徑。
6. CI 必須真實建置 Windows 及其他三個平台，並由靜態驗證檢查便攜路徑實作與打包流程。

## 實作步驟

1. 先新增純函式測試，固定便攜模式的選擇規則。
2. 在 `AppPath` 抽出 Windows 便攜資料路徑選擇，使用一次性寫入探測並清理探測檔案。
3. 將 `dataDir` 與 `cacheDir` 接到便攜路徑；系統資料目錄作為不可寫入時的回退。
4. 新增路徑靜態驗證，接入 PR 驗證工作流。
5. 執行本機測試、分析、格式與差異檢查，再推送並等待完整跨平台 CI。

## 相關檔案

- `lib/common/path.dart`
- `test/common/path_test.dart`
- `tool/verify_windows_portable_data.rb`
- `.github/workflows/pull-request-validation.yaml`
