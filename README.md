# Quota — Claude & Codex usage tracker for macOS

A native **multi-account Claude and OpenAI Codex subscription quota monitor**.
Keep remaining usage and reset times beside your editor in a small, pinnable
sticky-note window, or glance at your macOS menu bar.

**macOS 14+ · Apple Silicon download · SwiftUI/AppKit · MIT · No app subscription**

> 여러 Claude·Codex 구독 계정의 남은 사용량을 한 화면에서 확인하는 macOS 앱입니다.
> 현재 앱 UI는 한국어입니다. / The current app interface is in Korean.

## Install in one minute

The prebuilt community release needs **no Xcode, Swift toolchain or Claude CLI**.
Codex accounts additionally require the [Codex CLI](https://developers.openai.com/codex/cli/).

Download and inspect the versioned installer, then run it:

```sh
curl -fL https://raw.githubusercontent.com/gridi-ai/quota/v0.1.0/scripts/install.sh -o /tmp/quota-install.sh
less /tmp/quota-install.sh
bash /tmp/quota-install.sh
open "$HOME/Applications/Quota.app"
```

The script installs v0.1.0 to `~/Applications`, verifies SHA-256 and the bundle's
ad-hoc signature, uses no sudo, and leaves your account data untouched.
`--destination DIRECTORY` changes the install folder. To update an existing copy,
quit Quota and run the script with `--replace`; it refuses unrelated apps and symlinks.

Prefer a manual install? Download `Quota-0.1.0-macOS-arm64.zip` from
[Releases](https://github.com/gridi-ai/quota/releases), unzip and drag `Quota.app`
into Applications. Release checksums are in `SHA256SUMS`.

**Apple signing:** this preview is ad-hoc signed, **not notarized**. If macOS blocks
it, review the source and use System Settings → Privacy & Security → Open Anyway.
The installer does not disable Gatekeeper or remove quarantine attributes.
Intel Macs currently need the [source build](#build-from-source).

## What it does

- Multiple Claude and Codex accounts with explicit, verified account identities.
- **Remaining percentage**, progress bars, real quota windows and reset times.
- Compact / expanded widget, solid light / dark themes and optional always-on-top pin.
- Menu bar percentages for one selected account per provider; no cross-account averages.
- Independent five-minute refresh while running, manual refresh and refresh on wake.
- Last-known values and per-account errors instead of losing every account on one failure.
- Local-only state: no Quota server, analytics, cloud sync or app subscription.

This tracks **subscription limits**, not API billing or token-cost estimates.
It does not buy quota, switch model accounts or make model requests to measure usage.
Missing limits are unavailable, never guessed as 100%.

## Connect your first account

Open Quota, select **계정 추가** (Add account), choose a provider and enter an alias.

### Codex / ChatGPT

1. Install the official Codex CLI and select its executable in Quota.
2. A new account gets its own app-created `CODEX_HOME` profile and browser login.
3. After login, select **연결 확인** (Check connection).
4. For an existing profile, choose **기존 Codex 프로필 연결** and provide its directory.
   Use a different profile for each account.

Quota talks to `codex app-server` over local stdio; the CLI owns credential storage
and refresh. API-key accounts do not represent ChatGPT subscription quota.

### Claude / Claude Code

1. Quota opens your **default browser**, where Google or email login can complete.
2. Approve the provider's consent yourself, then copy the **entire authorization code**.
3. Select **인증 코드 입력…**, paste and choose **인증 코드로 연결**.
   Cmd+V, Ctrl+V, the paste button and Enter are supported.
4. Additional accounts require their own browser authorization.

The consent screen identifies **Claude Code**, because this preview uses its
compatible public OAuth client with PKCE and only `user:profile` scope.
After pairing, neither a browser nor Claude CLI must stay open.
Browser cookies and existing CLI tokens are not imported.

Claude usage uses an **undocumented provider OAuth endpoint**, not a supported
public Anthropic API contract. Codex's app-server protocol is also version-sensitive.
Provider changes can break retrieval; this app is not affiliated with OpenAI or Anthropic.

## Controls and privacy

Pin keeps the window on top. Closing hides the window; reopen it from the menu bar.
**Quit** stops refresh and Codex helpers. An asterisk in the menu bar means stale or
failed last-known data; a dash means unavailable.

Aliases, verified account identities and last snapshots are stored in
`~/Library/Application Support/Quota/accounts.json`. Claude tokens stay in
account-UUID-specific macOS Keychain entries. Authorization codes and PKCE
verifiers are never serialized into the account file.

Removing a row does **not** revoke provider grants, delete Keychain entries or
erase Codex profiles. To fully disconnect, also revoke the grant with the provider
and remove the corresponding local credentials yourself.

## Build from source

Requires macOS 14+ and **Swift 6+ / Xcode Command Line Tools**. No package dependencies.

```sh
git clone https://github.com/gridi-ai/quota.git
cd quota
bash scripts/build-app.sh
open dist/Quota.app
```

```sh
swift test --enable-code-coverage
swift run Quota --demo
```

Demo mode uses synthetic data without saving accounts or querying providers.
`--light`, `--dark` and `--expanded` select inspection modes.
Quit existing instances before switching modes.

## Project status

Early native macOS preview. The core suite has 41 passing tests. Real application
retrieval was checked with two distinct Codex accounts and one Claude account,
including Claude credentials surviving restart. Second-Claude live isolation,
actual sleep/wake and a complete live token-expiry cycle remain extended checks.

See [the publication audit](docs/PUBLICATION-AUDIT.md) and
[market / distribution assessment](docs/MARKET.md).
Report bugs through [GitHub Issues](https://github.com/gridi-ai/quota/issues),
including macOS / Quota / CLI versions and redacted errors. Never attach tokens,
authorization codes, account files or browser cookies.

## License

[MIT](LICENSE). Free source and community build. No paid recurring plan.
