#!/usr/bin/env bash
set -euo pipefail

# Removes the app and launchd agent. Config is left in place unless --purge.

BUNDLE_ID="com.billykov.cc-duck"
PLIST="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"

launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$HOME/Applications/cc-duck.app"

if [ "${1:-}" = "--purge" ]; then
  rm -f "$HOME/.claude/scripts/cc-duck.json"
  tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true
  echo "Uninstalled and purged (config + Accessibility grant removed)."
else
  echo "Uninstalled. Config kept at ~/.claude/scripts/cc-duck.json (use --purge to remove)."
fi
