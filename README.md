# Cloudflare Access

A KOReader plugin that injects [Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/identity/service-tokens/) service-token headers (`CF-Access-Client-Id`, `CF-Access-Client-Secret`) into outgoing HTTP/HTTPS requests, with a configurable hostname allowlist and an in-app log viewer for troubleshooting.

## What it does

If you self-host services behind Cloudflare Access (e.g. Calibre-Web, an OPDS catalog, a wiki) and use KOReader to browse or download from them, KOReader's requests will be blocked by Cloudflare unless the correct service-token headers are present. This plugin injects those headers automatically — no need to edit `.lua` files on your device.

## Why

The original solution was a [user patch](https://github.com/crocodilestick/koreader-cloudflare-auth-patch) that injected the headers globally into every HTTP request. That works, but it risks leaking your service token to third-party hosts (GitHub auto-updater, news feeds, dictionary lookups, etc.). This plugin replaces the patch with a proper, configurable KOReader plugin that supports a hostname allowlist.

## Installation

1. Download or clone this repository.
2. Copy the `CloudflareAccess.koplugin` directory into your KOReader `plugins/` folder:
   - **Android:** `koreader/plugins/`
   - **Kobo:** `.adds/koreader/plugins/`
   - **Kindle:** `linkss/koreader/plugins/` (or wherever KOReader is installed)
   - **Emulator:** `koreader/plugins/` in your KOReader source tree
3. Restart KOReader.

## Configuration

All configuration is done from KOReader's UI — no SSH, no editing `.lua` files.

Open **Settings → Network → Cloudflare Access** to:

- **Enable/disable** the plugin.
- **Set Client ID and Client Secret** — paste your Cloudflare Access service-token credentials.
- **Manage allowed domains** — add or remove hostnames that should receive the headers.
- **Set the log level** — Off / Warn / Info / Debug.
- **View logs** — inspect recent plugin activity in-app.
- **Test connection** — probe a URL and see the HTTP status, cf-ray, and redirect info.
- **About** — version info.

Settings are stored in `koreader/settings/cloudflareaccess.lua` on your device.

### Operating modes

| Mode | Allowlist | Behavior | Recommended? |
|------|-----------|----------|--------------|
| **Allowlist** (recommended) | ≥ 1 domain | Headers injected only for matching hosts | ✅ Yes |
| **Global** (fallback) | Empty | Headers injected for every host | ⚠ Discouraged |

**Allowlist mode** (recommended): Add the apex domains of your Cloudflare-protected services. A domain like `example.com` matches `example.com` and all subdomains (`*.example.com`). Headers are only sent to matching hosts.

**Global mode** (discouraged): If the allowlist is empty, the plugin injects headers into every outgoing request — matching the original patch's behavior. This is convenient for quick setup but risks leaking your service token to third-party hosts. A one-time warning is shown when this mode is active, and a ⚠ marker appears in the menu.

## Security notes

- **Where the secret is stored:** In `koreader/settings/cloudflareaccess.lua` on your device, in plain text. This is the same security level as KOReader's other settings. Protect your device accordingly.
- **How to rotate:** Generate a new service token in the Cloudflare dashboard, then update the Client ID and Client Secret in the plugin's menu.
- **Allowlist semantics:** Matching is case-insensitive. An entry `example.com` matches `example.com` and any subdomain (`sub.example.com`). Sibling domains like `evilexample.com` do **not** match. See [SECURITY.md](SECURITY.md) for the full threat model.

## Troubleshooting

**First step:** Open **Cloudflare Access → View logs** in the KOReader menu. This shows recent plugin activity without needing SSH.

The log level defaults to **Warn**. Switch to **Debug** while reproducing an issue, then switch back to reduce noise.

### Common log lines and their meanings

| Log line | Meaning |
|----------|---------|
| `injected for host=...` | Headers were injected for this host (it matched the allowlist) |
| `skip host=... (not in allowlist)` | The host did not match any allowlist entry; no headers sent |
| `hooks installed with empty allowlist` | The plugin is in global mode — headers go to every host |
| `host=... status=302 cf-ray=...` | The request got a redirect; check if it points to cloudflareaccess.com |

### Common HTTP status patterns

| Status | Meaning |
|--------|---------|
| **200** | Success — CF Access passed and the app served the request |
| **302 → cloudflareaccess.com** | CF Access authentication failed — check your Client ID and Secret |
| **401** | CF Access passed, but the app behind it (e.g. Calibre-Web) requires its own login |
| **403** | CF Access blocked the request — the service token may be expired or misconfigured |

### Finding the full log file

The in-app viewer shows the plugin's ring buffer (volatile, not persisted). For the full KOReader log, the file is at:

- **Android:** `koreader/crash.log`
- **Kobo:** `.adds/koreader/crash.log`
- **Kindle:** `linkss/koreader/crash.log` (or wherever KOReader is installed)
- **Desktop/emulator:** `koreader/crash.log` in the KOReader data directory

Use the **Log file** button in the viewer to see the absolute path on your device.

## Comparison with the upstream patch

| Feature | Upstream patch | This plugin |
|---------|---------------|-------------|
| Installation | Manual `.lua` file edit | Drop-in plugin directory |
| Configuration | Edit code constants | In-app UI |
| Host filtering | Allowlist (hardcoded) | Allowlist (editable at runtime) |
| Empty allowlist | Not applicable | Global mode with warning |
| Logging | `logger.info` only | Leveled ring buffer + in-app viewer |
| Test connection | No | Yes |
| Enable/disable | Restart required | Live toggle |

Upstream patch: [crocodilestick/koreader-cloudflare-auth-patch](https://github.com/crocodilestick/koreader-cloudflare-auth-patch)

## License

MIT — see [LICENSE](LICENSE).

## Credits

- [crocodilestick](https://github.com/crocodilestick) for the original Cloudflare Access user patch that this plugin replaces.
- The [KOReader](https://github.com/koreader/koreader) team for the excellent e-reader platform and plugin system.
