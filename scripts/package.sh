#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$REPO_ROOT/dist"
PLUGIN_DIR_NAME="CloudflareAccess.koplugin"

VERSION=$(sed -n 's/.*version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$REPO_ROOT/_meta.lua")

if [ -z "$VERSION" ]; then
    echo "ERROR: Could not read version from _meta.lua" >&2
    exit 1
fi

ZIP_NAME="${PLUGIN_DIR_NAME}-v${VERSION}.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

echo "=== Packaging $ZIP_NAME ==="
echo "Version: $VERSION"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

BUILD_DIR=$(mktemp -d)
VERIFY_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR" "$VERIFY_DIR"' EXIT

PKG_DIR="$BUILD_DIR/$PLUGIN_DIR_NAME"
mkdir -p "$PKG_DIR/lib" "$PKG_DIR/ui"

cp "$REPO_ROOT/_meta.lua"   "$PKG_DIR/"
cp "$REPO_ROOT/main.lua"    "$PKG_DIR/"
cp "$REPO_ROOT/hooks.lua"   "$PKG_DIR/"
cp "$REPO_ROOT/config.lua"  "$PKG_DIR/"
cp "$REPO_ROOT/README.md"   "$PKG_DIR/"
cp "$REPO_ROOT/LICENSE"     "$PKG_DIR/"
cp "$REPO_ROOT/SECURITY.md" "$PKG_DIR/"
cp -R "$REPO_ROOT/lib/"*    "$PKG_DIR/lib/"
cp -R "$REPO_ROOT/ui/"*     "$PKG_DIR/ui/"

cd "$BUILD_DIR"
zip -r "$ZIP_PATH" "$PLUGIN_DIR_NAME"

echo "Created: $ZIP_PATH"

unzip -q "$ZIP_PATH" -d "$VERIFY_DIR"

echo ""
echo "=== Package layout ==="
if command -v tree &>/dev/null; then
    tree "$VERIFY_DIR"
else
    find "$VERIFY_DIR" -not -type d | sort | sed "s|^$VERIFY_DIR/||"
    echo ""
    echo "--- directory tree ---"
    find "$VERIFY_DIR" | sort | sed "s|^$VERIFY_DIR/||"
fi

echo ""
echo "=== Done ==="
