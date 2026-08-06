# macOS 上游问题 #2281 与菜单栏性能设计

## 目标

针对已恢复到 SingLinkNetwork/FlClash 的两个问题进行有证据的处理：

- #1：上游 #2281，macOS 12.7.6 Intel 启动时因找不到 `sqlite3_stmt_isexplain` 而 Init Failed。
- #2：上游 #1644、#1985、#2033、#2141、#2180、#2263，macOS 菜单栏状态项高频重绘造成高 CPU，严重时影响 WindowServer/Dock。

本轮只把能在当前仓库和当前 macOS 环境中证明的改变合入；Windows、Android、Linux 的问题先记录来源、影响和验证缺口，不把“未测试”当成“已修复”。

## 已有证据

### 菜单栏高 CPU

上游讨论、采样结果和关联 PR 指向同一条链路：后台每秒刷新流量，状态项标题即使没有变化仍不断调用 `setTitle`；macOS 原生 `NSTextField` 的状态项布局会触发 `_updateReplicants` 高频重绘。上游 PR #2186 给出了低风险的 Dart 侧去重和隐藏时暂停刷新；tray_manager PR #2 给出了用自绘 `NSView` 替代 `NSTextField` 的原生修复。

### SQLite 启动失败

当前数据库使用 Drift 的 `NativeDatabase.createInBackground`。当前锁定的 sqlite3 运行库在 macOS 上会尝试加载 framework、进程符号和系统 `/usr/lib/libsqlite3.dylib`。因此必须先检查最终 macOS 包实际携带的 SQLite 动态库及符号，再决定是否修改依赖；不能仅凭一个旧系统报错直接做大版本升级。

## 设计

1. 在 Dart 层增加可单独测试的菜单栏标题缓存：只有标题真正变化时才调用原生 `setTitle`，销毁时清空缓存。
2. 在菜单栏隐藏且未开启流量标题时停止无用的每秒流量刷新；窗口重新显示或重新开启标题时恢复原行为。普通窗口、代理、规则和流量显示不得改变。
3. 原生 tray_manager 采用固定提交版本的修复，不依赖可变的分支。若验证后决定长期采用，优先放入 SingLinkNetwork 自有依赖或仓库内可审计的副本，并保留上游同步路径。
4. SQLite 先加入诊断和启动烟雾验证。只有在证明确实加载了系统旧库或最终包缺少兼容库后，才做最小依赖/打包修复；不在没有工具链和 macOS 12 Intel 实机证据时盲目升级 Drift/SQLite 大版本。

## 不在本轮范围内

- 不引入上游大型重构 PR #2271。
- 不声称已经验证 macOS 12 Intel、Windows、Android、Linux。
- 不关闭目标 issue，除非有对应平台的实际构建、启动或回归证据。

## 验收标准

- Dart 单元测试证明相同标题不会重复产生原生更新，隐藏状态不会产生更新，状态重置后可以再次更新。
- macOS release 构建成功，并检查包内动态库和符号来源。
- `flutter analyze --no-fatal-infos` 与相关测试通过。
- 目标 issue 中记录已做的修复、验证平台和仍缺失的跨平台证据。
