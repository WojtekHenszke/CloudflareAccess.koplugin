# Custom Header Rules

Custom header rules let you inject arbitrary HTTP headers into outgoing
requests, beyond the built-in Cloudflare Access service-token headers.
This enables integration with other authentication proxies and services.

## Quick start

1. Open **Settings → Network → Cloudflare Access → Custom header rules**.
2. Tap **Add rule**.
3. Enter the header name (e.g. `X-Api-Key`), value, and optional domains.
4. Tap **Save**.

The rule is active immediately. Use **Test connection** to verify which
headers are being injected.

## Rule fields

| Field | Description | Example |
|-------|-------------|---------|
| **Header name** | RFC 7230 token (letters, digits, `-`, `_`, etc.) | `X-Api-Key` |
| **Header value** | The string value to inject (max 4096 chars, no CR/LF) | `my-secret-key` |
| **Domains** | Comma-separated hostnames. Empty = inherit global allowlist | `example.com, api.example.com` |
| **Enabled** | Toggle the rule on/off without deleting | ✓ |
| **Secret** | When on (default), value is masked in UI (`abcd…wxyz`) | ✓ |

## Domain scoping

Each rule can optionally specify its own domain list:

- **Per-rule domains set** (e.g. `api.example.com`) — the rule applies
  only to matching hosts, ignoring the global allowlist.
- **Per-rule domains empty** — the rule inherits the global CF Access
  allowlist. If the global allowlist is also empty, the rule matches
  every host (with a warning).
- **Per-rule domains empty + global allowlist set** — the rule applies
  to the same hosts as CF Access.

Domain matching is case-insensitive and supports subdomains:
`example.com` matches `example.com` and `*.example.com`.

## Header injection order

When multiple sources define the same header name, the first one wins:

1. **Caller-supplied** — headers already set by KOReader code are never
   overwritten.
2. **CF Access** — `CF-Access-Client-Id` / `CF-Access-Client-Secret`.
3. **Custom rules** — applied in array order. Later rules with the same
   name overwrite earlier custom rules, but never overwrite caller or
   CF Access headers.

## Use case examples

### Authelia

Authelia uses a `Authorization` header or a custom `X-Authelia-Url`
header depending on your configuration.

```
Header name: Authorization
Header value: Basic dXNlcjpwYXNz
Domains: auth.example.com
Secret: ✓
```

### Static API key

```
Header name: X-Api-Key
Header value: your-api-key-here
Domains: api.example.com
Secret: ✓
```

### Google IAP

Google Identity-Aware Proxy uses a JWT assertion header.

```
Header name: X-Goog-Iap-Jwt-Assertion
Header value: <your-jwt>
Domains: app.example.com
Secret: ✓
```

### Tailscale Funnel

```
Header name: X-Tailscale-Auth
Header value: your-tailscale-auth-token
Domains: funnel.ts.net
Secret: ✓
```

### Non-secret header (e.g. client identification)

```
Header name: X-KOReader-Client
Header value: koreader-1.0
Domains: (empty — inherits global allowlist)
Secret: ✗
```

## Security considerations

- **Values are never logged**, even when `secret = false`. The `secret`
  flag only controls UI masking.
- **Values are stored in plain text** in
  `koreader/settings/cloudflareaccess.lua`, same as CF Access credentials.
- **Empty per-rule domains + empty global allowlist** = the rule matches
  every host. A one-time warning is shown on startup.
- Use the **Test connection** feature to verify which headers are being
  injected for a given URL.

See [SECURITY.md](../SECURITY.md) for the full threat model.
