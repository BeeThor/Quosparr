[English](./README.md) · 简体中文 · [繁體中文](./README_ZH_HANT.md) · [한국어](./README_KO.md) · [日本語](./README_JA.md) · [Русский](./README_RU.md) · [Français](./README_FR.md)

<div align="center">

<img src="Resources/AppIcon.png" alt="Quosparr logo" width="128" height="128">

# Quosparr

<sub><i>名称取自 <b>Quo</b>ta（额度）+ <b>Sparr</b>ow（麻雀）</i></sub>

一只停在菜单栏里的小麻雀，替你守着 Codex 与 Grok 的额度。

Quosparr 是面向 macOS、Windows、Linux 的原生菜单栏 / 系统托盘应用，展示 Codex 与 Grok 额度、reset credits、API 等价成本与本机会话，两个供应商各自独立管理多账号。

</div>

## 亮点

**Codex**

- 查看 5 小时、每周与附加额度窗口的剩余额度，以及当前账号、订阅等级和到期时间
- 查看 reset credits 数量、状态与过期时间
- 根据官方周用量百分比与每日 Credits 推算本周额度，并与往周对比，便于发现额度缩水
- Codex 重置动态：查看今天 Codex 速率限制是否已重置，可单独设置刷新间隔（数据来自 [Did Codex Reset](https://didcodexreset.com)）
- 多账号：浏览器登录、导入本机 `auth.json`、粘贴 token / JSON（含 `/auth/session`）、导入文件或添加 API Key；确认后原子写入 `~/.codex/auth.json` 完成切号
- 查看最近会话、项目与状态，并修复本机会话索引

**Grok**

- 通过官方 CLI chat-proxy 计费接口查看包含额度、Build / Imagine / Chat 拆分、周 / 月周期、预付余额和按需用量
- 多个 OAuth / SuperGrok 账号：隔离登录、导入当前登录、粘贴凭据、刷新、别名、排序与显式切号
- 查看本地 Grok CLI 日志中的最近会话

**两个供应商通用**

- 常驻 `Codex | Grok` 标签切换，菜单栏与右键菜单跟随所选供应商
- 查看今天、本周期、上周期、本月或自定义范围的 API 等价成本与 Token 用量
- 年度 Token 用量图表，支持热力图、折线图和柱状图（按日 / 按周 / 累计）
- 支持浅色、深色、跟随系统外观，以及 English、简体中文、繁體中文、한국어、日本語、Русский、Français
- 内置在线更新，macOS 14+ 提供桌面组件

## 截图

<table>
  <tr>
    <th colspan="2">主面板</th>
    <th colspan="2">API 等价成本</th>
    <th colspan="2">订阅额度推算</th>
  </tr>
  <tr>
    <td colspan="2" align="center" valign="top"><img src="docs/images/1.webp?v1" alt="Quosparr 主面板" width="240"></td>
    <td colspan="2" align="center" valign="top"><img src="docs/images/3.webp?v1" alt="Quosparr API 等价成本" width="240"></td>
    <td colspan="2" align="center" valign="top"><img src="docs/images/6.webp?v1" alt="Quosparr 订阅额度推算" width="240"></td>
  </tr>
  <tr>
    <th colspan="3">多账号</th>
    <th colspan="3">显示设置</th>
  </tr>
  <tr>
    <td colspan="3" align="center" valign="top"><img src="docs/images/4.webp?v1" alt="Quosparr 多账号" width="370"></td>
    <td colspan="3" align="center" valign="top"><img src="docs/images/5.webp?v1" alt="Quosparr 显示设置" width="370"></td>
  </tr>
  <tr>
    <th colspan="6">Windows 设置与 Grok 面板</th>
  </tr>
  <tr>
    <td colspan="6" align="center" valign="top"><img src="docs/images/2.webp?v1" alt="Quosparr Windows 设置与 Grok 面板" width="780"></td>
  </tr>
</table>

截图展示的是 v1 在 macOS 与 Windows 上的界面

## 安装

请从 [GitHub Releases](https://github.com/Licoy/Quosparr/releases) 下载，并按系统和 CPU 架构选择安装包：

| 系统 | 安装包 | 安装方式 |
| --- | --- | --- |
| macOS 12+（Apple Silicon / Intel） | `Quosparr-macos-arm64.dmg` / `Quosparr-macos-x86_64.dmg`，或同名 `.zip` | 将 `Quosparr.app` 拖入 `Applications` |
| Windows 10 / 11（amd64 / arm64） | `Quosparr.Setup.<version>.<arch>.exe` | 用户级安装到 `%LOCALAPPDATA%\Programs\Quosparr`，不需要管理员权限 |
| Linux（amd64 / arm64） | `quosparr-<version>-linux-<arch>.tar.gz` 与 `install.sh`，或 `quosparr_<version>_<arch>.deb` | 在 tar.gz 同目录运行 `sh install.sh` 安装到 `~/.local`，或用包管理器安装 deb |

各安装包都随包携带对应架构的 SQLite 运行库，首次启动不会联网下载。首次启动时默认开启开机自启，可在 **控制台 → 通用 → 开机自启** 中修改

暂未提供 Homebrew 安装，目前请使用 DMG 或 ZIP 安装

之前使用过 CodexRunway？请参阅[升级指南](docs/upgrade-from-codexrunway_ZH.md)

### macOS 安全提示

macOS 包目前为 ad-hoc signed，未经公证。若提示“无法验证开发者”，请右键点击 `Quosparr.app` 选择“打开”，或在“系统设置 → 隐私与安全性”中点击“仍要打开”

若提示应用已损坏，通常是下载隔离属性导致。将应用放入 `Applications` 后执行：

```bash
xattr -dr com.apple.quarantine /Applications/Quosparr.app
```

### Linux 依赖

Linux 需要 GTK3、AppIndicator、支持托盘的桌面，以及可用的 Secret Service 会话（如 GNOME Keyring 或 KWallet）用于保存代理凭据。deb 已声明这些依赖，并通过包管理器更新

## 使用前提

- 建议本机已安装并使用 Codex。Codex 数据来自 `CODEX_HOME`，默认 `~/.codex`，Windows 默认 `%USERPROFILE%\.codex`
- 仅支持 `file` 凭据存储（Codex `config.toml` 中未设置 `cli_auth_credentials_store` 时即为该方式）；`keyring`、`auto`、`ephemeral` 会提示不支持，并阻止导入与切号
- 使用 Grok 面板前需要安装 [官方 Grok CLI](https://docs.x.ai/build/overview)：

  ```bash
  curl -fsSL https://x.ai/cli/install.sh | bash
  ```

- Grok 账号与额度仅支持 OAuth / SuperGrok 及兼容的 legacy session。可执行 `grok login --oauth`、在应用内登录、导入当前登录或粘贴凭据 JSON；仅 API Key 的登录不会加入托管账号。设置了 `GROK_HOME` 时使用该目录，否则使用 `~/.grok`

## 桌面组件

桌面组件需要 macOS 14 或更高版本，Windows 与 Linux 不提供。共有四类组件：额度总览、Token 趋势、关键指标和 Codex 重置动态；每个组件都可在“编辑小组件”中选择 Codex、Grok 或两者，点击后跳转到对应页面

快照位于 `~/.quosparr/widget-snapshot.json`，权限为 `0600`，只包含非密钥派生数据，不含邮箱、账号 ID、token、认证 JSON 或事件原文；主程序是唯一写入者，组件只读

## 网络代理

在 **控制台 → 通用 → 网络** 中选择 **跟随系统**、HTTP 或 SOCKS5，自定义代理支持用户名和密码。设置覆盖应用发起的 Codex 与 Grok 请求、CLI 操作、公开状态与价格源以及软件更新；不修改系统代理，浏览器登录页和已经运行的外部 CLI 沿用各自设置

修改仅在点击 **保存代理设置** 后生效。**测试连接** 使用当前草稿读取公开更新源，不发送账号凭据，也不保存草稿。代理密码分别保存在 macOS 钥匙串、Windows 凭据管理器和 Linux Secret Service 中。配置错误、凭据不可用或自定义代理失败时不会自动改为直连

## 隐私

- Quosparr 的自有数据保存在 `~/.quosparr`，不向 `~/.codex` 写入应用缓存，默认只保存非密钥的派生数据
- 多账号凭据是唯一例外，保存在 `~/.quosparr/accounts/<id>/auth.json`（目录 `0700`、文件 `0600`，原子写入；Windows 使用仅当前用户可访问的 ACL），账号索引不包含 token
- 官方 `~/.codex/auth.json` 仅在 OAuth 刷新回写或你确认切号时写入；刷新非当前账号只更新账号库副本
- Grok 凭据从 `$GROK_HOME/auth.json` 读取，托管副本位于 `~/.quosparr/accounts/grok-<stable-id>/auth.json`。Grok 切号只替换 OAuth / 兼容 legacy scope，保留 API Key 与未知 scope，且仅保证新会话使用新账号；已运行的 Grok 进程不会被终止，可能写回旧账号，因此切换前会给出提示
- 会话修复只处理 `session_index.jsonl`，写入前先备份；不会删除 `~/.codex/sessions` 与 `~/.codex/archived_sessions` 下的文件
- API 等价成本基于本机会话日志计算，不上传会话内容
- token 与 API Key 不会写入日志、自检输出或 issue 模板
- Codex 重置动态与更新检查只读取公开数据，不发送账号、token 或会话内容

## 数据来源

- **Codex 额度 / reset credits / 官方用量**：使用本机凭据请求 ChatGPT / Codex 官方后端接口；官方用量属于当前账号，可能延迟或修订
- **周额度推算**：非官方，根据周用量百分比与每日 Credits 推算（1000 Credits ≈ 40 美元，版本 `credits-usd-2026-08-26`），`quota-estimate-history.json` 只保存派生的 Credits 与占用率
- **Codex API 等价成本**：基于本机会话日志，使用内置价格表 `openai-builtin-2026-09-27`，在线官方价格表采用 `openai-docs-` 版本；未知模型不报告精确费用
- **Grok 额度**：只使用官方 CLI chat-proxy `/v1/billing?format=credits` 接口；不读取浏览器 Cookie、不从本地日志伪造额度，也不混入 API 账单
- **Grok API 等价成本**：基于本地 `turn_completed` 用量和价格表 `xai-builtin-2026-09-27`，区分输入、缓存、输出及长上下文价格；`costUsdTicks` 属于订阅额度记账，不作为 API 等价成本
- **Codex 重置动态**：来自公开接口 [didcodexreset.com/api/status.json](https://didcodexreset.com/api/status.json)，非官方，仅供参考，可能延迟
- 图表中的“官方统计（多端）”属于当前账号，“本机日志（全部本机会话）”扫描本机且可能跨账号；两者不是包含关系，也不能相减，Codex 两种按日统计均按 UTC 日界比较

## 开发

主程序使用 Go 与 [mygo](https://github.com/egoist/mygo) 原生界面编写，Go 与 mygo 版本以 `go.mod` 为准；macOS 桌面组件扩展仍使用 Swift

```bash
go test ./...
go vet ./...
go build ./...
```

开发运行请使用临时 HOME 和独立偏好域，避免触碰真实账号与设置：

```bash
QUOSPARR_TEST_HOME="$(mktemp -d)"
HOME="$QUOSPARR_TEST_HOME" QUOSPARR_PREFS_DOMAIN=com.quosparr.app.v1-test go run .
HOME="$QUOSPARR_TEST_HOME" QUOSPARR_PREFS_DOMAIN=com.quosparr.app.v1-test go run . --self-check
```

自检不请求网络、不读取凭据，目前覆盖版本、平台、自有目录权限、锁状态，以及 Codex auth 与会话索引是否存在；其余诊断会标记为 `not ported yet`

构建 macOS 开发包（禁用更新器，可选 `ARCH=arm64` 或 `ARCH=x86_64`）：

```bash
V1_DEVELOPMENT_PACKAGE=1 bash Scripts/package-v1-app.sh
```

Windows / Linux 打包与发布校验见 [docs/v1-release.md](docs/v1-release.md)，贡献说明见 [CONTRIBUTORS.md](CONTRIBUTORS.md)

## 社区支持

- [LinuxDO](https://linux.do/)

## 许可证

本项目遵循仓库中的 [LICENSE](LICENSE)
