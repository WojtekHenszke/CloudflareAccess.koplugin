# Security Policy

## Threat model

This plugin handles Cloudflare Access service tokens, which are sensitive
credentials. The primary threats are:

1. **Token leakage to third-party hosts** — If headers are injected into
   requests to hosts that are not Cloudflare-protected, the service token
   is exposed to those hosts' operators.
2. **Token exposure via logs** — If secrets are logged, they could be
   visible in `crash.log` or the in-app log viewer.
3. **Token storage on device** — The token is stored in a plain-text Lua
   settings file on the device.

## Operating modes

### Allowlist mode (recommended)

Headers are injected **only** for hostnames matching the user-defined
allowlist. This is the default behavior when at least one domain is
configured.

**Risk:** Low. Headers only reach explicitly allowlisted hosts.

### Global mode (discouraged)

When the allowlist is empty, headers are injected into **every** outgoing
HTTP/HTTPS request. This preserves the behavior of the original user patch
for onboarding convenience.

**Risks:**
- The service token is sent to every host KOReader contacts, including:
  - GitHub release servers (auto-updater)
  - NewsDownloader feed sources
  - Wikipedia and dictionary lookup servers
  - OPDS catalogs from other providers
  - Any redirect target (a 302 from an allowlisted host to a third-party
    host would carry the token)
- Any of these hosts' operators could log or misuse the token.

**Recommended remediation:** Add at least one allowlist entry. The plugin
shows a one-time warning dialog and a persistent ⚠ marker when global
mode is active.

## What data is stored where

| Data | Location | Format | Persisted? |
|------|----------|--------|------------|
| Client ID | `koreader/settings/cloudflareaccess.lua` | Plain text | Yes |
| Client Secret | `koreader/settings/cloudflareaccess.lua` | Plain text | Yes |
| Allowed domains | `koreader/settings/cloudflareaccess.lua` | Plain text | Yes |
| Log entries (ring buffer) | In-memory only | Redacted | No |
| Forwarded log entries | `koreader/crash.log` | Redacted | Yes (KOReader's log) |

The settings file has the same security level as KOReader's other settings
files (e.g. `wallabag.lua`, `SSH.lua`). Protect physical access to your
device accordingly.

## Token rotation

1. Generate a new service token in the Cloudflare dashboard
   (Zero Trust → Access → Service Tokens).
2. Open KOReader → Settings → Network → Cloudflare Access.
3. Update the Client ID and Client Secret.
4. (Optional) Revoke the old token in the Cloudflare dashboard.

## Redaction

The plugin's log facade redacts secret-like strings before forwarding to
either KOReader's logger or the in-memory ring buffer:

- Hex strings ≥ 32 characters → `<redacted>`
- Base64-ish strings ≥ 40 characters → `<redacted>`

This is defense in depth. The plugin never intentionally logs secrets,
Authorization headers, or full response bodies. Only host, path, HTTP
status, and `cf-ray` are logged.

## What this plugin does NOT do

- **No mTLS** — Only service tokens are supported, not mutual TLS.
- **No SSO / JWT** — No JWT-based Cloudflare Access authentication.
- **No automatic Cloudflare API integration** — Tokens are not fetched or
  rotated via the Cloudflare API.
- **No encryption at rest** — The settings file is plain text, matching
  KOReader's conventions.

## Responsible disclosure

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public GitHub issue.
2. Email: `<security-email-placeholder>` (to be filled before public release).
3. Include a description of the issue and steps to reproduce.
4. Allow a reasonable timeframe for a fix before public disclosure.
