# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/WojtekHenszke/CloudflareAccess.koplugin/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/WojtekHenszke/CloudflareAccess.koplugin/releases/tag/v0.1.0
