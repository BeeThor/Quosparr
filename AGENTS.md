# AGENTS.md

## 项目定位

Quosparr 是一个原生 macOS 状态栏应用，用 Swift 编写，用于读取本机 Codex 配置和会话数据，展示配额、reset credits、API 等价成本，并修复本机会话索引。

`v1` 分支以 Go + mygo/ui 实现 macOS、Windows、Linux 原生托盘主应用，macOS 保留 Swift WidgetKit 扩展与系统桥接；Swift 主应用、`Package.swift` 和 `Tests/` 继续保留，作为兼容基线与应急回滚能力，三端正式发布前必须完成隔离安装升级验收

## 技术边界

- 使用 Swift 6、SwiftPM、AppKit、SwiftUI、Foundation。
- macOS 最低版本为 12.0。
- 默认不引入第三方依赖；标准库和系统框架能解决的问题不要加包。在线更新功能批准使用 Sparkle。
- 不创建 Xcode project，除非用户明确要求。
- 状态栏应用必须保持 `LSUIElement=true`，不要显示 Dock 图标。
- Go 版本和依赖版本以 `go.mod` 为准，首轮固定 Go 1.27.1、mygo v0.4.1；不将框架升级与迁移改动混在一起
- mygo/ui 只负责原生界面与框架服务，不引入 WebView 前端；业务核心不能依赖 UI
- purego 仅用于必要的平台 API、SQLite 和 Swift 桥接边界，按平台拆分并检查 ABI、资源生命周期与错误传播；不用它增加业务抽象
- macOS Go 主应用使用 mygo 更新器，不嵌入 Sparkle 运行库；保留 Sparkle 公钥与 Quosparr Swift 的独立 ZIP / appcast，旧身份 appcast 仅提供手动下载链接，不做跨 bundle ID 自动安装
- 安装包必须随包携带相应架构的 SQLite 运行库，首次运行不得联网下载；Widget 与桥接嵌入后从内到外签名，最终签名之后才生成发布归档

## 隐私与安全

- 不要在日志、测试输出、README、issue 模板中输出 access token、refresh token、API key。
- Quosparr 自有目录统一使用 `~/.quosparr`，默认只保存非密钥的派生数据，不将应用缓存写入 `~/.codex`。
- macOS 偏好是现有系统 UserDefaults 的兼容例外，写入 `com.quosparr.app`，旧域 `com.github.codex-runway` 和 `dev.licoy.codex-runway` 仅用于一次性导入；Windows / Linux 偏好保存在自有目录，代理密码使用各平台安全存储，不写普通设置
- 多账号凭据是唯一例外：仅允许存放在 `~/.quosparr/accounts/<id>/auth.json`（目录 `0700`、文件 `0600`，原子写入）。账号索引 `index.json` 不得包含 token。
- Windows 凭据与相应目录、临时写入文件使用仅当前用户可访问的 protected ACL，并关闭权限继承，不能以 chmod 代替实际权限检查
- 读取 `~/.codex/auth.json` 时只使用必要字段。
- 修改官方 `~/.codex/auth.json` 仅限：OAuth refresh 回写、以及用户主动切号时的原子写入。
- 刷新非当前托管账号 token 时只写账号库副本，不得写官方 `auth.json`；刷新当前账号时同步官方 auth 与账号库副本。
- 会话修复只允许处理 `session_index.jsonl`，写入前必须备份。
- 不删除 `~/.codex/sessions/**`、`~/.codex/archived_sessions/**` 或全局状态文件。

## 代码约定

- 核心逻辑放在 `Sources/QuosparrCore`，UI 放在 `Sources/Quosparr`。
- Go 入口为 `main.go`，原生 UI 与系统协调放在 `internal/app`，后台协调放在 `internal/runway`，存储 / 平台 / 网络 / 本地化边界分别放在 `internal/store`、`internal/platform`、`internal/netx`、`internal/l10n`
- Go 业务模块放在 `internal/codex`、`internal/codexapi`、`internal/grok`、`internal/usage`、`internal/sessions`、`internal/alerts`、`internal/estimate`、`internal/export`、`internal/resettoday`；UI 经业务 API 读取结果，不直接解析 JSON 或扫描文件
- UI 不直接解析 JSON、不直接扫描文件；通过 core API 获取结果。
- 所有用户可见文案必须通过 `L10n`，新增 key 需要同时补英文和简体中文。
- Go 文案通过 `internal/l10n` 与现有附加文案入口，新增用户可见 key 必须补齐英文、简体中文、繁体中文、韩文、日文、俄文、法文，Swift 新文案同样遵守七语言完整性
- 函数保持短小，优先用简单结构体和函数，不做多 provider 抽象。
- 错误信息可以面向用户，但不要包含本地密钥或完整认证 JSON。
- 新行为优先补 `Tests/QuosparrCoreTests`。
- Go 新行为在对应 `internal/*` 包补必要测试，兼容数据使用 Swift 对照 fixture，不能以交叉编译替代 Windows ACL、系统权限或真机安装验收
- 保留 `QUOSPARR_DEV_*` 环境钩子；手动开发运行使用临时 HOME 和 `QUOSPARR_PREFS_DOMAIN=<测试域>`，不触碰开发机真实账号、UserDefaults、Keychain、登录项或生产 feed，结束后退出自行启动的进程

## 常用命令

```bash
go test ./...
go vet ./...
go build ./...
go test -race -count=1 ./internal/...
go run . --self-check
V1_DEVELOPMENT_PACKAGE=1 bash Scripts/package-v1-app.sh
bash Scripts/test-swift.sh
swift run Quosparr --self-check
bash Scripts/package-app.sh
```

`go run . --self-check` 当前只检查基础目录、锁与文件存在性，并明确列出尚未移植的诊断；不能将其描述为 Swift 完整自检；开发打包必须显式设置 `V1_DEVELOPMENT_PACKAGE=1`，生产默认 `0` 并要求发布环境中的更新签名私钥；Windows / Linux 交叉构建及完整发布校验见 `docs/v1-release.md`

## 文档规则

- README 和源码不要包含外部参考应用名称、链接或代码片段。
- 用户可见文档应说明隐私边界、ad-hoc signed app、开发命令和功能状态。
- 价格表必须带版本日期；未知模型不要估算为精确费用。
- 根目录 `README*.md` 已按 v1 Quosparr 重写：语言切换位于左上角首行，名称、小号斜体的名称由来概述（加粗 **Quo**ta + **Sparr**ow 取字部分）与简介水平居中，不单设名称由来章节，不嵌入视频；安装部分按全新安装说明，旧版升级说明放在 `docs/upgrade-from-codexrunway*.md` 七种语言并由首页链接；七种语言保持相同结构与事实，修改任一语言时同步其余六种；`README_EN.md` 仅作跳转
- 候选资产和清单准备完成不代表已正式发布或已通过真机验收
- 隔离验收按 `docs/v1-acceptance-checklist.md` 与 `docs/v1-isolated-update-proxy.md` 执行，未修改且未重签的历史应用须保留真实 Sparkle 归档验签；不得改生产源或关闭 TLS 校验

## v1 分支说明（从 README 迁入）

以下集中保留原 v1 README 中的平台、安装、更新、迁移、开发与隐私说明；README 是面向用户的精简版本，细节与验收边界以本节和 `docs/v1-*.md` 为准

### 产品与功能状态

Quosparr v1 面向 macOS、Windows、Linux，主程序使用 Go + mygo/ui 原生菜单栏 / 系统托盘，macOS 保留 Swift WidgetKit 扩展；提供 Codex 与 Grok 额度、重置动态、reset credits、API 等价成本、本机会话和各供应商独立的多账号管理

- 当前仍是开发中的候选版本，尚未宣告正式发布，现有截图展示 v1 在 macOS 与 Windows 上的界面
- 首次无偏好配置的启动显示设置并保存默认偏好，已有配置或从旧版迁移的用户普通启动时仅驻留菜单栏；主动点击设置或显式传入 `--settings` 才再次打开设置，日常 Dev 重启不附加该参数
- Codex 支持配额窗口、订阅到期、reset credits、周额度推算与历史对比，Grok 展示官方 CLI chat-proxy 额度及 Build / Imagine / Chat 拆分、周期、预付余额和按需使用情况
- 两个供应商均保留账号管理、本地 Token 用量图表、API 等价成本与最近会话，图表支持热力图、折线图和柱状图；Codex 另有会话索引修复与公开重置动态
- 主应用支持浅色、深色、跟随系统，以及英文、简体中文、繁体中文、韩文、日文、俄文、法文
- 自动测试和交叉编译不能替代三端安装、桌面、迁移与回滚验收，待验收项见 [验收清单](docs/v1-acceptance-checklist.md) 与 [发布说明](docs/v1-release.md)

### 平台与安装

项目仓库为 [Licoy/Quosparr](https://github.com/Licoy/Quosparr)，候选包按系统和 CPU 架构选择；只有对应 Release 公开后才向用户提供下载，不把已生成的本地资产或草稿描述为已发布版本

| 系统 | 候选包 | 安装方式 |
| --- | --- | --- |
| macOS 12+ Apple Silicon / Intel | `Quosparr-macos-arm64.dmg` / `Quosparr-macos-x86_64.dmg`，或同名 `.zip` | 退出旧实例后将 `Quosparr.app` 放入 `Applications` |
| Windows 10 / 11 amd64 / arm64 | `Quosparr Setup <version> <arch>.exe` | 用户级安装到 `%LOCALAPPDATA%\Programs\Quosparr`，不要求管理员身份 |
| Linux amd64 / arm64 | `quosparr-<version>-linux-<arch>.tar.gz` 与 `install.sh`，或 `quosparr_<Debian-version>_<arch>.deb` | tar.gz 使用可写用户目录，deb 通过包管理器安装到 `/opt/quosparr` |

- Linux 需要 GTK3、AppIndicator、支持托盘的桌面，以及用于代理凭据的可用 Secret Service 会话；缺少桌面库时应明确提示，deb 通过包管理器更新，只读或受限目录需要在可写位置手动安装
- macOS 包目前为 ad-hoc signed，未公证，首次打开可能需要在系统“隐私与安全性”中授权；Developer ID 签名与公证单独推进
- Homebrew cask 生成器已准备，外部 `Licoy/homebrew-tap` 尚未同步新名称，当前工作流也暂停了 cask 准备与分发；恢复并发布后才使用 `brew install --cask licoy/tap/quosparr`，此前使用 DMG，详见 [Homebrew 同步说明](docs/v1-homebrew.md)
- 普通卸载保留本地数据，显式 `--zap` 只清理 Quosparr 数据，不清理保留的旧应用目录或官方 Codex / Grok 文件

### 更新与 Swift 用户迁移

- 三端使用 mygo 原生更新器检查、下载、验签、安装和重启，自动检查遵循保存的偏好，默认不自动下载安装；开发包禁用更新器
- 当前 Actions 只生成 Release 草稿，正式公开发布、latest 提升、固定 `v1-beta` 频道更新和 Homebrew 阶段均暂停；Beta 候选标签为 `beta-v<version>`，草稿标记 prerelease 且 `latest=false`
- 恢复 Beta 分发后使用独立的 `v1-beta` 频道与不可变候选 Release，二者均为 prerelease 且 `latest=false`，不改生产 latest；稳定版标签 `v<version>` 必须匹配 `mygo.json` 的版本
- 新身份是 `com.quosparr.app`、`quosparr://` 和 `~/.quosparr`，旧用户需退出旧应用后手动安装；旧 Sparkle feed 只提供下载页入口，Quosparr Swift 构建使用独立 feed，不能跨 bundle ID 自动安装
- 首次启动复制旧应用数据并导入缺失偏好，保留原目录和已有 Quosparr 数据；新目录已存在时也补入缺失文件与账号 ID，新账号元数据、当前选择和数据库整组优先
- 迁移采用暂存事务并支持中断恢复，完成标记防止已删除的旧账号重新导入；引用的代理凭据在系统凭据库内复制，可能需要授权，迁移本身不修改官方 Codex / Grok 登录文件
- 新身份不自动继承系统权限，安装后重新添加桌面组件并检查登录项；已识别旧登录项在新项启用确认后清理，保留用户禁用选择，macOS 遗留的旧 SMAppService 注册可能仍需用户在系统登录项中手动移除
- 旧名称的账号包仍可导入，新导出采用 `quosparr-accounts`；保留 `Package.swift`、`Sources/Quosparr*` 和 `Tests/` 作为 Swift 兼容基线与应急回滚，`swift run Quosparr` 启动的是 Swift 应用

### 官方 CLI 目录与凭据

- Codex 账号、会话与统计使用 `CODEX_HOME`，默认 `~/.codex`，Windows 默认 `%USERPROFILE%\.codex`
- 从 Codex `config.toml` 读取 `cli_auth_credentials_store`，未设置或 `file` 受支持，`keyring`、`auto`、`ephemeral` 明确报不支持并阻止官方凭据导入与切号
- 后台同步不恢复缺失的登录文件，刷新 token 不覆盖外部切号、退出登录或并发凭据变更；会话目录读取失败时在备份、替换索引前终止修复
- Grok 依赖官方 CLI，使用 `GROK_HOME` 或默认 `~/.grok`；多账号与额度只支持 OAuth / SuperGrok 及兼容 legacy session，可通过 `grok login --oauth`、应用内登录、导入当前登录或粘贴凭据添加，API Key 单独登录不加入托管账号
- Grok 官方凭据为 `$GROK_HOME/auth.json`，托管副本为 `~/.quosparr/accounts/grok-<stable-id>/auth.json`，无 token 的索引为 `~/.quosparr/accounts/grok-index.json`
- Grok 切号只替换 OAuth / 兼容 legacy scope，保留 API Key 与未知 scope，仅保证新会话使用新账号；不强制终止外部 Grok 进程，切换前提示旧进程可能写回旧账号

### 开发运行与 Widget

使用 `go.mod` 固定的 Go 1.27.1 和 mygo v0.4.1，默认隔离运行示例：

```bash
QUOSPARR_TEST_HOME="$(mktemp -d)"
HOME="$QUOSPARR_TEST_HOME" QUOSPARR_PREFS_DOMAIN=com.quosparr.app.v1-test go run . --self-check
V1_DEVELOPMENT_PACKAGE=1 bash Scripts/package-v1-app.sh
# 可选 ARCH=arm64 或 ARCH=x86_64
```

- Go 自检不请求网络、不解析凭据，只报告版本 / 平台、自有目录权限与可写性、锁状态、Codex auth 与会话索引是否存在；已有自有目录会创建并移除临时写入探针
- 脱敏认证摘要、token 有效性、会话 dry-run 摘要、Grok CLI 版本、Grok 认证状态与身份仍明确列为 `not ported yet`，不能描述为 Swift 完整诊断
- Go 桌面开发入口为 `go run .`，默认沿用临时 HOME 与独立偏好域；系统集成与升级验收使用一次性 VM，非隔离 Dev 运行仅在用户明确要求时执行
- macOS 开发包输出到 `build/v1-<arch>/darwin-<goarch>/Quosparr.app` 和 `Quosparr-macos-<arch>-dev.zip`，目前保留正式 bundle 身份；正式打包默认 `V1_DEVELOPMENT_PACKAGE=0`，签名私钥通过发布环境提供
- Widget 要求 macOS 14+，保留四类组件、供应商选择和深链，Windows / Linux 不提供 WidgetKit；现有桌面组件的升级接续仍需实际验收
- Widget 快照为 schema 1，位于 `~/.quosparr/widget-snapshot.json`，权限 `0600`，只含非密钥派生数据，不含邮箱、账号 ID、token、完整认证 JSON 或事件原文；主程序是唯一写入者，组件只读

### 代理、隐私与统计口径

- 代理支持跟随系统、HTTP、SOCKS5 及用户名 / 密码，覆盖应用发起的 Codex / Grok 请求、CLI 操作、公开状态 / 价格源和软件更新；不修改系统代理，浏览器登录页与已经运行的外部 CLI 沿用各自设置
- 代理修改仅在“保存代理设置”后生效，进行中的更新保持启动时配置；“测试连接”只用当前草稿读取公开更新源，不发送账号凭据、不保存草稿；错误配置、凭据不可用或自定义代理失败不能自动直连
- 非密钥派生数据保存在 `~/.quosparr`，Windows / Linux 偏好在自有目录；代理密码分别保存在 macOS Keychain、Windows Credential Manager、Linux Secret Service
- API 等价成本默认来自本机会话日志，不上传会话内容；周额度推算只保存 `quota-estimate-history.json` 中的派生 Credits 与占用率，不保存 token 或密钥
- 图表“官方统计（多端）”属于当前账号，可能延迟或修订；“本机日志（全部本机会话）”可能跨账号，不能视为包含关系或相减；Codex 两种按日统计均按 UTC 日界比较
- Codex 内置 API 价格表版本为 `openai-builtin-2026-09-27`，在线官方价格表采用 `openai-docs-` 版本，未知模型不报告精确费用；订阅额度推算使用 `credits-usd-2026-08-26`，1000 Credits 约对应 40 美元，属于非官方推算
- Grok 额度只使用官方 CLI chat-proxy `/v1/billing?format=credits`，不读取浏览器 Cookie、不从本地日志伪造额度、不混入 API 账单；API 等价成本使用本地 `turn_completed` 用量和 `xai-builtin-2026-09-27`，区分输入、缓存、输出及长上下文价格，`costUsdTicks` 不作为 API 等价成本

### 首次推送边界

- 提交源代码、测试、依赖锁定文件、必要资源与 fixture；生成的 glyph / 本地化 Go 源文件和兼容测试的 SQLite、JSONL、压缩样本属于源码或测试资产，不按扩展名批量删除
- 构建目录、安装包输出、Python 字节码、IDE 用户状态、本地临时目录、发布说明生成结果及签名私钥不进入 Git；清理只针对确认可重新生成的本地文件
- 推送 `main` / `v1` 触发普通 CI，开发打包无需发布 Secrets；版本标签触发签名打包与 Release 草稿，需要 `MYGO_UPDATE_PRIVATE_KEY`、`SPARKLE_PUBLIC_KEY`、`SPARKLE_PRIVATE_KEY`，私钥必须匹配配置公钥
- 本地测试通过不等于线上 Actions 已通过，首次推送后需核对 Windows / Linux 原生安装与 SQLite 验证、macOS 双架构打包的实际结果
