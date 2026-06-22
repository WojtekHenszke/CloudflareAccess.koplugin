# Architecture

## Overview

CloudflareAccess.koplugin is a KOReader plugin that monkey-patches
`socket.http.request` and `ssl.https.request` to inject Cloudflare Access
service-token headers for allowlisted hosts.

## Plugin lifecycle

```
KOReader starts
  └─ pluginloader scans plugins/ for *.koplugin directories
     └─ loads _meta.lua (metadata: name, fullname, description)
     └─ loads main.lua (entrypoint)
        └─ WidgetContainer:extend{ name = "cloudflareaccess" }
        └─ CloudflareAccess:init()
           ├─ log.setLevel(config.getLogLevel())
           ├─ log.setCapacity(config.getLogCapacity())
           ├─ hooks.install(get_config closure)
           │    ├─ resolve socket.http / ssl.https via package.loaded
           │    ├─ save original .request functions
           │    ├─ replace with wrappers
           │    └─ warn if enabled + empty allowlist
           ├─ self.ui.menu:registerToMainMenu(self)
           └─ schedule empty-allowlist warning (if needed)
```

The plugin is loaded once at startup. The `init()` function installs the
hooks and registers the menu. All subsequent configuration changes
(enable/disable, credential edits, allowlist changes, log level) take
effect immediately because the wrappers read config on every call.

## Hook installation

### Why monkey-patch at `package.loaded` level

KOReader modules require `socket.http` and `ssl.https` at load time and
cache local references:

```lua
local http = require("socket.http")
-- ... later ...
http.request(url)
```

By the time our plugin loads, these modules are already in
`package.loaded`. We resolve them the same way:

```lua
local http_module = package.loaded["socket.http"] or require("socket.http")
```

We then replace `http_module.request` with our wrapper. This works because
Lua tables are references — modules that captured `http` as a local still
see the same table, and our modified `.request` is what gets called.

### Why we can't fully unhook

A full unhook is unreliable because other modules may have captured a
local reference to the *original* `request` function before our plugin
loaded:

```lua
-- some KOReader module, loaded before our plugin
local request = require("socket.http").request  -- captures original
-- ... later ...
request(url)  -- bypasses our hook
```

For this reason, the plugin relies on the `enabled` flag for runtime
toggling rather than unhooking. When `enabled = false` (or credentials are
empty), the wrapper is a perfect no-op: it passes arguments and return
values through unchanged.

## Wrapper behavior

```
incoming request (table or string form)
  │
  ├─ get_config() → { enabled, client_id, client_secret, domains }
  │
  ├─ disabled or no creds? → pass through (no-op)
  │
  ├─ get_host(url) → lowercase hostname
  │
  ├─ is_allowed(host, domains)?
  │   ├─ YES → inject headers (if not already set), call original
  │   └─ NO  → call original unchanged
  │
  └─ log result (host, path, status, cf-ray) at dbg level
```

### String form promotion

LuaSocket's `http.request` accepts two forms:
- **Table form:** `http.request({ url = ..., headers = ... })` → returns `1, code, headers, status`
- **String form:** `http.request("https://...")` → returns `body, code, headers, status`

When the host matches and the caller used the string form, the wrapper
promotes it to table form (using `ltn12.sink.table` to collect the body),
injects headers, calls the original, and returns the concatenated body to
preserve the string-form contract.

### Header collision

The wrapper never overwrites `CF-Access-Client-Id` or
`CF-Access-Client-Secret` headers that the caller already set. It checks
both canonical (`CF-Access-Client-Id`) and lowercased
(`cf-access-client-id`) keys.

## Allowlist matching algorithm

```
is_allowed(host, domains):
  1. Lowercase host, strip trailing dot (FQDN form)
  2. If domains is empty → return true (unsafe fallback)
  3. For each domain in domains:
     a. Lowercase domain, strip trailing dot
     b. If host == domain → return true (exact match)
     c. If host ends with "." .. domain → return true (subdomain match)
  4. Return false
```

The leading dot in the subdomain suffix check prevents sibling-domain
false positives: `evilwojtasord.com` does not match `wojtasord.com`
because `evilwojtasord.com` does not end with `.wojtasord.com`.

## Logging architecture

```
                    ┌──────────────────────────────────┐
  hooks.lua ──────► │  lib/log.lua (facade)            │
  main.lua ───────► │                                  │
  test_connection ► │  1. Check level (drop if below)  │
                    │  2. Format message (lazy)        │
                    │  3. Redact secrets                │
                    │  4. Forward to KOReader logger    │ ──► crash.log
                    │     with "[CFAccess] " prefix     │
                    │  5. Append to ring buffer         │
                    └──────────────────────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────────┐
                    │  In-memory ring buffer            │
                    │  (default 200 entries, volatile)  │
                    │  Never persisted to disk          │
                    └──────────────────────────────────┘
                                   │
                                   ▼
                    ┌──────────────────────────────────┐
                    │  ui/log_viewer.lua (TextViewer)   │
                    └──────────────────────────────────┘
```

### Why two destinations?

- **KOReader's logger** → writes to `crash.log` on disk. Useful for
  debugging via SSH/USB. The `[CFAccess]` prefix makes plugin entries
  easy to grep.
- **Ring buffer** → in-memory, shown in the in-app viewer. No SSH needed.
  Volatile by design: secrets-adjacent metadata (hostnames, paths) does
  not outlive the session.

### Redaction

Both destinations receive redacted messages. The `redact()` function
masks:
- Hex strings ≥ 32 characters (CF client IDs)
- Base64-ish strings ≥ 40 characters (CF client secrets)

This is defense in depth: even if a secret accidentally ends up in a log
message, it is masked before reaching either `crash.log` or the ring
buffer.

### Log levels

| Level | Value | What's logged |
|-------|-------|---------------|
| off | 0 | Nothing (no-op) |
| err | 1 | Errors only |
| warn | 2 | Errors + warnings (default) |
| info | 3 | + install/uninstall, test connection |
| dbg | 4 | + per-request injected/skip lines, status, cf-ray |

When set to `off`, the facade returns immediately without formatting —
zero cost per call.

## Known limitations

- **Can't fully unhook:** Modules that captured a local reference to the
  original `request` function before our plugin loaded bypass the hook.
  Mitigated by installing hooks early (plugin loads at startup).
- **Turbo HTTP client not hooked:** KOReader's async `HTTPClient` (used by
  some features) uses `turbo`, not `socket.http`/`ssl.https`. Requests
  through that path are not intercepted.
- **No per-request UI:** Hooking is silent except in logs, by design.
- **Service tokens only:** No mTLS, no JWT-based Access.
