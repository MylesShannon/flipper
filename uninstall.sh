#!/bin/bash
set -eu

[ "$(id -u)" != 0 ] || { echo "Run as yourself, not with sudo: ./uninstall.sh"; exit 1; }
LABEL=com.mylesshannon.flipper
INSTALLED="/Applications/Flipper.app"
case "${1:-}" in
  "") mode=uninstall ;;
  --delete-settings) mode=everything ;;
  --permissions-only) mode=permissions ;;
  *) echo "Usage: ./uninstall.sh [--delete-settings | --permissions-only]" >&2; exit 2 ;;
esac
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

if [ "$mode" != permissions ] && [ -x "$INSTALLED/Contents/MacOS/Flipper" ]; then
  "$INSTALLED/Contents/MacOS/Flipper" unregister
fi
pkill -x Flipper || true
for _ in $(seq 1 10); do
  pgrep -x Flipper >/dev/null || break
  sleep 0.5
done

# Accessibility is in the system's permissions database, so it asks for your password. tccutil finds the app by its
# bundle identifier, so this runs before the app is removed.
sudo tccutil reset Accessibility "$LABEL" >/dev/null
echo "Reset Flipper's Accessibility access."
if [ "$mode" = permissions ]; then
  open "$INSTALLED"
  echo "Opened Flipper, so it asks for Accessibility now."
  exit 0
fi

rm -rf "$INSTALLED"
# So the next copy opened from Applications registers itself to open at login again.
defaults delete "$LABEL" loginItemOffered 2>/dev/null || true
if [ "$mode" = everything ]; then
  defaults delete "$LABEL" 2>/dev/null || true
  echo "Uninstalled Flipper and deleted its settings."
else
  echo "Uninstalled Flipper. Its settings stay."
fi
