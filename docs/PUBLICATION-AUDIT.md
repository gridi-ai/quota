# Public repository audit

## Scope

The initial public tree contains only application/core sources, synthetic tests,
package metadata, the bundle manifest, build script, README, license, ignore rules and this
report. No previous Git history exists to publish.

Excluded from publication:

- Agent sessions, memory, evidence captures, knowledge graphs and local settings.
- Design-review drafts and internal verification ledgers.
- Build products, Swift caches and generated application bundles.
- Runtime account files, Codex credentials, environment files and private keys.

The public repository never contains a user's Application Support directory,
Keychain contents, browser data or Codex profile.

## Review

Public source and fixture literals are scanned with Gitleaks before upload.
Separate searches check personal home paths, account emails, private endpoints,
credential formats and machine/user identifiers.

The Claude OAuth client ID is a public client identifier, not a client secret.
PKCE verifier/state values are generated at runtime. Token-like literals in tests
are synthetic fixtures; reserved example email domains identify fixture accounts.
Runtime authentication grants are not committed.

Claude tokens are held in account-specific app-owned Keychain entries. Codex
credentials remain in the selected CLI profile. Account metadata and last-known
usage stay on the user's machine. There is no application backend or telemetry.

An audit is specific to the published tree; it is not a claim that all files on a
developer's machine are safe to upload.

## Initial result

Before the first public upload:

- Gitleaks staged-tree scan: no leaks found.
- Source searches: no personal home paths or real account email literals.
- Credential-shaped test strings: synthetic transport fixtures only.
- Excluded files: verified against the explicit staged-file allowlist.
- `swift test --enable-code-coverage`: 41 tests passed.

Future public changes and downloadable bundles require a separate scan. Local
builds are not published simply because the source scan passed.

## First downloadable bundle

The Apple Silicon 0.1.0 release is built without debug information and with a
source-file prefix map. Binary string inspection found no personal home paths,
developer identifiers, private-key blocks or credential-format literals.
The ZIP contains only Quota.app's executable, manifest and signature files, not
account data or build caches. Packaging omits resource forks and extended attributes.
The code signature verifies, but it is ad-hoc: no Developer ID or notarization is
claimed. SHA-256 accompanies the ZIP; checksums do not authenticate an Apple identity.
