# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-06-22

### Added

- **Custom HTTP header rules** — define arbitrary user-defined HTTP
  headers (e.g. `Authorization`, `X-Api-Key`) with per-rule hostname
  scoping, secret masking, and enable/disable toggles. Enables use cases
  beyond Cloudflare Access: Authelia, Authentik, Google IAP, Tailscale
  Funnel, static API keys, and more.
- Schema v2 migration: idempotent, non-destructive upgrade from v0.1.0
  settings. Adds `custom_headers = {}` if missing.
- Typed config accessors with deep-copy semantics: `getCustomHeaders`,
  `setCustomHeaders`, `addCustomHeader`, `updateCustomHeader`,
  `removeCustomHeader`, `getCustomHeader`, `setCustomHeaderEnabled`.
- `lib/header_rules.lua`: pure helpers for rule validation (RFC 7230
  token grammar, CRLF injection prevention, length caps), domain
  matching (`effective_domains`, `applies`), and value masking
  (`mask_preview`, `redact_for_log`).
- Header injection order: caller-supplied > CF Access > custom rules.
  Later custom rules with the same name overwrite earlier ones, but
  never overwrite caller or CF Access headers.
- Per-rule domain scoping: empty per-rule domains inherit the global
  allowlist. Empty per-rule + empty global = match everything (with
  warning).
- Separate one-time warning for custom rules with no effective allowlist
  (`warned_empty_allowlist_custom` ack flag, independent from CF Access
  warning).
- In-app UI for custom header rules: list view with per-rule submenu
  (Edit, Enabled toggle, Secret toggle, Delete), multi-field edit dialog
  with validation.
- Test connection now shows which headers were injected (names only,
  never values), grouped by source (CF Access / custom).
- `docs/custom-headers.md`: detailed setup guide with use case examples.
- Redaction sanity tests verifying header values never leak into logs.

### Changed

- Hooks refactored: shared `apply_headers()` code path for table-form
  and promoted string-form requests. Custom headers applied after CF
  Access injection.
- About dialog updated to v0.2.0 with broader description.
- README, SECURITY.md, and architecture docs updated to cover custom
  header rules.

## [0.1.0] - 2026-06-22

### Added

- Cloudflare Access service-token header injection (`CF-Access-Client-Id`,
  `CF-Access-Client-Secret`) into outgoing HTTP/HTTPS requests via
  `socket.http` and `ssl.https` monkey-patching.
- Hostname allowlist with exact-match and subdomain matching
  (`example.com` matches `*.example.com`). Case-insensitive, trailing-dot
  normalization.
- Empty-allowlist global mode (discouraged) with one-time warning dialog
  and persistent ⚠ menu marker.
- In-app configuration UI: enable/disable toggle, credential editors
  (Client ID with masked preview, Client Secret with password input),
  allowlist domain editor (add/remove with validation), log level
  selector (Off/Warn/Info/Debug).
- Test connection diagnostic: probes a URL and shows HTTP status, cf-ray,
  redirect location, and contextual hints.
- In-app log viewer with ring buffer (200 entries, volatile), redaction
  of secret-like strings, and buttons for Refresh, Clear, Copy, and
  showing the log file path.
- Leveled logging facade over KOReader's logger with `[CFAccess]` prefix,
  lazy formatting, and defense-in-depth redaction.
- Live configuration: enable/disable, credential edits, allowlist changes,
  and log level take effect immediately without restart.
- MIT license, README, CONTRIBUTING guide, architecture docs, and
  SECURITY.md with threat model.

[Unreleased]: https://github.com/WojtekHenszke/CloudflareAccess.koplugin/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/WojtekHenszke/CloudflareAccess.koplugin/releases/tag/v0.2.0
[0.1.0]: https://github.com/WojtekHenszke/CloudflareAccess.koplugin/releases/tag/v0.1.0
