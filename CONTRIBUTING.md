# Contributing to Cloudflare Access

Thanks for your interest in contributing! This plugin is developed against the
[KOReader](https://github.com/koreader/koreader) frontend APIs.

## Getting the code

This repository includes the KOReader source as a **git submodule** (under
`koreader/`) for LSP autocompletion and code reference only. The submodule is
**not** required at runtime — the plugin works without it on a device.

### Clone with submodules

```sh
git clone --recurse-submodules https://github.com/WojtekHenszke/CloudflareAccess.koplugin.git
```

If you already cloned without `--recurse-submodules`, initialise the submodule
afterwards:

```sh
git submodule update --init --recursive
```

> **Note:** The submodule is pinned to a specific stable KOReader release tag
> (`v2026.03`). You normally do not need to change it.

## Editor setup

A `.luarc.json` is included for
[lua-language-server](https://github.com/LuaLS/lua-language-server) (LuaLS). It
points the LSP at `koreader/frontend/` so `require()` calls resolve to real
KOReader modules, and tells the server not to diagnose the submodule's own
files.

---

_Linting, testing and emulator instructions will be added in a later task._
