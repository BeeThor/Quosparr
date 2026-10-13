English · [简体中文](./README_ZH.md) · [繁體中文](./README_ZH_HANT.md) · [한국어](./README_KO.md) · [日本語](./README_JA.md) · [Русский](./README_RU.md) · [Français](./README_FR.md)

<div align="center">

<img src="Resources/AppIcon.png" alt="Quosparr logo" width="128" height="128">

# Quosparr

<sub><i>Named from <b>Quo</b>ta + <b>Sparr</b>ow</i></sub>

A small sparrow perched in your menu bar, keeping watch over your Codex and Grok quota.

Quosparr is a native menu bar / system tray app for macOS, Windows, and Linux. It shows Codex and Grok quota, reset credits, API-equivalent cost, and local sessions, with separate multi-account management for each provider.

</div>

## Highlights

**Codex**

- Remaining quota for the 5-hour, weekly, and additional windows, plus the current account, subscription tier, and expiration.
- Reset credit count, status, and expiration time.
- Weekly allowance estimate from the official weekly percent and daily Credits, compared with previous weeks to spot quota cuts.
- Codex Reset Updates: whether Codex rate limits have reset today, with its own refresh interval (data from [Did Codex Reset](https://didcodexreset.com)).
- Multiple accounts: browser sign-in, import local `auth.json`, paste token / JSON (including `/auth/session`), import files, or add an API key. Switching after confirmation atomically writes `~/.codex/auth.json`.
- Recent sessions, projects, and status, plus repair of the local session index.

**Grok**

- Included quota, Build / Imagine / Chat breakdown, weekly / monthly periods, prepaid balance, and on-demand usage via the official CLI chat-proxy billing API.
- Multiple OAuth / SuperGrok accounts with isolated sign-in, current-login import, credential paste, refresh, aliases, ordering, and explicit switching.
- Recent sessions from local Grok CLI logs.

**Both providers**

- Always-visible `Codex | Grok` tabs; the menu bar and context menu follow the selected provider.
- API-equivalent cost and token usage for today, the current cycle, the previous cycle, this month, or a custom range.
- Year-to-date token usage chart as a heatmap, line, or bar chart (daily / weekly / cumulative).
- Light, dark, and system appearance; English, 简体中文, 繁體中文, 한국어, 日本語, Русский, Français.
- Built-in updates, and desktop widgets on macOS 14+.

## Screenshots

<table>
  <tr>
    <th colspan="2">Main panel</th>
    <th colspan="2">API-equivalent cost</th>
    <th colspan="2">Subscription quota estimate</th>
  </tr>
  <tr>
    <td colspan="2" align="center" valign="top"><img src="docs/images/1.webp?v1" alt="Quosparr Main panel" width="240"></td>
    <td colspan="2" align="center" valign="top"><img src="docs/images/3.webp?v1" alt="Quosparr API-equivalent cost" width="240"></td>
    <td colspan="2" align="center" valign="top"><img src="docs/images/6.webp?v1" alt="Quosparr Subscription quota estimate" width="240"></td>
  </tr>
  <tr>
    <th colspan="3">Multi-account</th>
    <th colspan="3">Display settings</th>
  </tr>
  <tr>
    <td colspan="3" align="center" valign="top"><img src="docs/images/4.webp?v1" alt="Quosparr Multi-account" width="370"></td>
    <td colspan="3" align="center" valign="top"><img src="docs/images/5.webp?v1" alt="Quosparr Display settings" width="370"></td>
  </tr>
  <tr>
    <th colspan="6">Windows settings and Grok panel</th>
  </tr>
  <tr>
    <td colspan="6" align="center" valign="top"><img src="docs/images/2.webp?v1" alt="Quosparr Windows settings and Grok panel" width="780"></td>
  </tr>
</table>

The screenshots show the v1 interface on macOS and Windows.

## Installation

Download from [GitHub Releases](https://github.com/Licoy/Quosparr/releases) and pick the package for your system and CPU:

| System | Package | How to install |
| --- | --- | --- |
| macOS 12+ (Apple Silicon / Intel) | `Quosparr-macos-arm64.dmg` / `Quosparr-macos-x86_64.dmg`, or the `.zip` with the same name | Drag `Quosparr.app` into `Applications` |
| Windows 10 / 11 (amd64 / arm64) | `Quosparr.Setup.<version>.<arch>.exe` | Per-user install into `%LOCALAPPDATA%\Programs\Quosparr`; no administrator rights needed |
| Linux (amd64 / arm64) | `quosparr-<version>-linux-<arch>.tar.gz` with `install.sh`, or `quosparr_<version>_<arch>.deb` | Run `sh install.sh` next to the tarball to install into `~/.local`, or install the deb with your package manager |

Every package ships the SQLite runtime for its architecture, so the first launch never downloads anything. On first launch, Quosparr enables launch at login by default; change it in **Control Panel → General → Launch at login**.

Homebrew installation is not available yet; use the DMG or ZIP for now.

If you used CodexRunway before, see the [upgrade guide](docs/upgrade-from-codexrunway.md).

### macOS security prompts

macOS builds are currently ad-hoc signed and not notarized. If macOS says the developer cannot be verified, right-click `Quosparr.app` and choose Open, or go to System Settings → Privacy & Security and click Open Anyway.

If macOS says the app is damaged, it is usually the download quarantine attribute. After moving the app into `Applications`, run:

```bash
xattr -dr com.apple.quarantine /Applications/Quosparr.app
```

### Linux requirements

Linux needs GTK3, AppIndicator, a desktop with tray support, and a working Secret Service session (for example GNOME Keyring or KWallet) to store proxy credentials. The deb declares these dependencies and is updated through the package manager.

## Requirements

- Codex installed and used on this machine is recommended. Codex data comes from `CODEX_HOME` (default `~/.codex`, or `%USERPROFILE%\.codex` on Windows).
- Only the `file` credential store is supported (the default when `cli_auth_credentials_store` is unset in Codex `config.toml`). `keyring`, `auto`, and `ephemeral` are reported as unsupported and block importing and switching accounts.
- The Grok panel requires the [official Grok CLI](https://docs.x.ai/build/overview):

  ```bash
  curl -fsSL https://x.ai/cli/install.sh | bash
  ```

- Grok accounts and quota support OAuth / SuperGrok and compatible legacy sessions only. Run `grok login --oauth`, sign in from the app, import the current login, or paste credential JSON. API-key-only logins are not added as managed accounts. `GROK_HOME` is used when set, otherwise `~/.grok`.

## Desktop Widgets

Widgets require macOS 14 or later; Windows and Linux do not have them. Four widget types are available: quota overview, token trend, a key metric, and Codex Reset Updates. Each widget can select Codex, Grok, or both in Edit Widget, and tapping it opens the matching page.

The snapshot lives at `~/.quosparr/widget-snapshot.json` with `0600` permissions and contains only non-secret derived data: no email, account ID, token, auth JSON, or raw event text. The main app is the only writer; widgets only read it.

## Network Proxy

In **Control Panel → General → Network**, choose **Follow System**, HTTP, or SOCKS5; custom proxies support username and password. The setting covers app-initiated Codex and Grok requests, CLI operations, public status and pricing feeds, and software updates. The system proxy is not changed, and browser sign-in pages and already-running external CLIs keep their own settings.

Changes apply only after **Save Proxy Settings**. **Test Connection** fetches the public update feed with the current draft, without sending account credentials or saving the draft. Proxy passwords are stored in the macOS Keychain, Windows Credential Manager, or Linux Secret Service. Invalid settings, unavailable credentials, or a failed custom proxy never fall back to a direct connection.

## Privacy

- Quosparr keeps its own data in `~/.quosparr` and writes no app cache into `~/.codex`. Only non-secret derived data is stored by default.
- Multi-account credentials are the only exception: they are stored under `~/.quosparr/accounts/<id>/auth.json` (directory `0700`, file `0600`, written atomically; Windows uses an ACL that only the current user can access). The account index contains no tokens.
- Official `~/.codex/auth.json` is written only for an OAuth refresh or when you confirm an account switch. Refreshing a non-current account updates only its library copy.
- Grok credentials are read from `$GROK_HOME/auth.json`; managed copies live at `~/.quosparr/accounts/grok-<stable-id>/auth.json`. A Grok switch replaces only OAuth / compatible legacy scopes and keeps API-key and unknown scopes. It is guaranteed only for new sessions; running Grok processes are not terminated and may write the previous account back, so the app warns before switching.
- Session repair only touches `session_index.jsonl` and backs it up first. Files under `~/.codex/sessions` and `~/.codex/archived_sessions` are never deleted.
- API-equivalent cost is computed from local session logs. Session contents are not uploaded.
- Tokens and API keys are never written to logs, self-check output, or issue templates.
- Codex Reset Updates and update checks fetch only public data; no account, token, or session content is sent.

## Data Sources

- **Codex quota / reset credits / official usage**: official ChatGPT / Codex backend APIs, using your local credentials. Official usage belongs to the current account and may lag or be revised.
- **Weekly quota estimate**: unofficial, extrapolated from the weekly percent and daily Credits (1000 Credits ≈ $40, version `credits-usd-2026-08-26`). Only derived Credits and percents are saved in `quota-estimate-history.json`.
- **Codex API-equivalent cost**: local session logs priced with the built-in table `openai-builtin-2026-09-27`; the online official table uses `openai-docs-` versions. Unknown models are not reported as exact costs.
- **Grok quota**: only the official CLI chat-proxy `/v1/billing?format=credits` endpoint. No browser cookies, no quota inferred from local logs, and no API billing mixed in.
- **Grok API-equivalent cost**: local `turn_completed` usage priced with `xai-builtin-2026-09-27`, covering input, cached, output, and long-context rates. `costUsdTicks` is subscription accounting and is not used as API-equivalent cost.
- **Codex Reset Updates**: the public feed at [didcodexreset.com/api/status.json](https://didcodexreset.com/api/status.json). Unofficial, advisory only, and may be delayed.
- In the chart, “Official stats (all devices)” belongs to the current account, while “Local logs (all sessions)” scans this machine and may span accounts. They are not a subset of each other and should not be subtracted; Codex daily values for both use UTC days.

## Development

The main app is written in Go with [mygo](https://github.com/egoist/mygo) native UI; the Go and mygo versions are pinned in `go.mod`. The macOS widget extension remains in Swift.

```bash
go test ./...
go vet ./...
go build ./...
```

Run against a temporary HOME and a separate preferences domain so your real accounts and settings are untouched:

```bash
QUOSPARR_TEST_HOME="$(mktemp -d)"
HOME="$QUOSPARR_TEST_HOME" QUOSPARR_PREFS_DOMAIN=com.quosparr.app.v1-test go run .
HOME="$QUOSPARR_TEST_HOME" QUOSPARR_PREFS_DOMAIN=com.quosparr.app.v1-test go run . --self-check
```

The self-check makes no network request and reads no credentials. It currently covers the version, platform, own-directory permissions, locks, and whether Codex auth and the session index exist; other diagnostics are listed as `not ported yet`.

Build a macOS development package (updater disabled; optionally `ARCH=arm64` or `ARCH=x86_64`):

```bash
V1_DEVELOPMENT_PACKAGE=1 bash Scripts/package-v1-app.sh
```

See [docs/v1-release.md](docs/v1-release.md) for Windows / Linux packaging and release checks, and [CONTRIBUTORS.md](CONTRIBUTORS.md) for contribution notes.

## Community

- [LinuxDO](https://linux.do/)

## License

This project follows the repository [LICENSE](LICENSE).
