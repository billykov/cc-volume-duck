#!/usr/bin/env bash
set -euo pipefail

# cc-volume-duck installer: compile Swift -> ad-hoc signed .app -> launchd autostart.
# macOS only. Needs Xcode command line tools (swiftc).

BUNDLE_ID="com.billykov.cc-duck"
APP="$HOME/Applications/cc-duck.app"
SCRIPTS="$HOME/.claude/scripts"
CONFIG="$SCRIPTS/cc-duck.json"
PLIST="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v swiftc >/dev/null || { echo "swiftc not found. Run: xcode-select --install"; exit 1; }

echo "Compiling..."
mkdir -p "$APP/Contents/MacOS"
swiftc -O "$SRC/cc-duck.swift" -o "$APP/Contents/MacOS/cc-duck"
cp "$SRC/Info.plist" "$APP/Contents/Info.plist"

# Ad-hoc sign so TCC can track the bundle. Re-signing changes the cdhash and
# invalidates any existing Accessibility grant -> a re-grant is expected here.
echo "Signing (ad-hoc)..."
codesign --force --deep --sign - "$APP"

# Config: keep an existing one, install the default on first run.
mkdir -p "$SCRIPTS"
[ -f "$CONFIG" ] || cp "$SRC/cc-duck.json" "$CONFIG"

# launchd: start on login, restart if it dies.
mkdir -p "$HOME/Library/LaunchAgents"
sed "s|__APP__|$APP/Contents/MacOS/cc-duck|g" "$SRC/$BUNDLE_ID.plist" > "$PLIST"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo
echo "Installed and running."
echo "macOS will prompt for Accessibility permission on first launch."
echo "Toggle 'cc-duck' ON in System Settings -> Privacy & Security -> Accessibility."
echo "Then hold space in iTerm to duck the volume; release to restore it."
