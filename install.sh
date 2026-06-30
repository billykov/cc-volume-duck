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

# Optional: opt into IDE-embedded terminals (VS Code, Cursor). Only ask on a real
# TTY; default no. This just seeds "extra_terminals" in the config, which the app
# hot-reloads - you can also edit it by hand later, no reinstall needed.
if [ -t 0 ]; then
  echo
  echo "Supported by default: iTerm, Terminal, Warp, Ghostty, Kitty, and more."
  echo "Also enable VS Code / Cursor? Heads up: space will then duck whenever those"
  echo "apps are frontmost - including while you edit a file, not just the terminal pane."
  printf "Enable VS Code / Cursor support? [y/N] "
  read -r reply
  if [[ "$reply" =~ ^[Yy] ]]; then
    /usr/bin/python3 - "$CONFIG" <<'PY'
import json, sys
p = sys.argv[1]
cfg = json.load(open(p))
cfg["extra_terminals"] = sorted(set(cfg.get("extra_terminals", [])) | {"code", "cursor"})
json.dump(cfg, open(p, "w"), indent=2)
PY
    echo "Enabled. (Remove \"code\"/\"cursor\" from $CONFIG to undo.)"
  fi
fi

# launchd: start on login, restart if it dies. Logs to ~/Library/Logs/cc-duck.log.
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
LOG="$HOME/Library/Logs/cc-duck.log"
sed -e "s|__APP__|$APP/Contents/MacOS/cc-duck|g" -e "s|__LOG__|$LOG|g" "$SRC/$BUNDLE_ID.plist" > "$PLIST"
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo
echo "Installed and running. Log: $LOG"
echo "macOS will prompt for Accessibility permission on first launch."
echo "Toggle 'cc-duck' ON in System Settings -> Privacy & Security -> Accessibility."
echo "It starts on its own within ~10s once granted; then hold space in iTerm to duck."
