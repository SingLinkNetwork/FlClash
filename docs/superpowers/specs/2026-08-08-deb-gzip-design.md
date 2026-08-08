# Linux DEB gzip 壓縮修復設計

## 背景

上游 [#1029](https://github.com/chen08209/FlClash/issues/1029) 回報，部分 Debian 衍生系統（例如 UOS）無法安裝 FlClash 的 `.deb`，原因是套件內的 `data.tar` 使用 zstd 壓縮。現有 Linux 打包流程透過固定版本的 `flutter_distributor` 呼叫系統 `dpkg-deb --build`，沒有明確指定壓縮格式；因此產物會跟著 runner 上的 dpkg-deb 預設值變化。

## 目標

- Linux `.deb` 的 control/data tar 成員固定使用 gzip。
- 不改變套件內容、檔名、安裝腳本或 RPM/AppImage 產物。
- CI 直接檢查真實 `.deb` 的 Debian ar 成員，防止設定只停留在原始碼而沒有反映到產物。
- 保留目前固定的 `flutter_distributor` revision 與補丁流程，讓修復可追溯、可回滾。

## 非目標

- 不承諾在所有未支援的舊 Debian 版本上完成安裝測試。
- 不替換整個 Linux 打包器。
- 不修改 zstd 壓縮的 RPM、AppImage 或其他格式。

## 設計

在 `tool/flutter_distributor_startup_wm_class.patch` 中為 Debian maker 的 `dpkg-deb --build` 增加 `--compression=gzip`。這個補丁只作用於我們固定的打包器 checkout。

新增 `tool/verify_linux_deb_compression.rb`：

1. 掃描指定 `dist` 目錄中的 `.deb`。
2. 使用 Debian ar 成員表檢查 `debian-binary`、`control.tar.gz`、`data.tar.gz`。
3. 拒絕 `control.tar.zst`、`data.tar.zst` 或其他未知壓縮後綴。

現有 `tool/verify_linux_packages.rb` 仍負責解包與 desktop entry 驗證；新的檢查專門驗證上游問題的壓縮格式，避免責任混在一起。

## 驗收

- 靜態驗證確認補丁指定 `--compression=gzip`。
- 單元測試確認 gzip 套件通過、zstd 套件被拒絕、缺少必要成員被拒絕。
- Linux CI 先產出真實 `.deb`，再執行壓縮格式驗證。
- 完整 PR CI/CD 的所有檢查與 `CI complete` 通過後，才關閉下游追蹤問題。
