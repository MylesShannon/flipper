#!/bin/bash
set -eu
trap 'echo "install.sh stopped at line $LINENO. The output above says why." >&2' ERR
[ "$(id -u)" != 0 ] || { echo "Run as yourself, not with sudo: ./install.sh" >&2; exit 1; }
[ $# -le 1 ] || { echo "Usage: ./install.sh [path/to/Flipper.app]" >&2; exit 2; }
if [ $# = 1 ]; then
  [ -d "$1" ] || { echo "$1 isn't a Flipper.app from the official releases." >&2; exit 1; }
  STAGE=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
fi
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

if [ $# = 1 ]; then
  codesign --verify --deep --strict \
    -R='anchor apple generic and identifier "com.mylesshannon.flipper" and certificate leaf[subject.OU] = "6KUEM6Q5E2"' \
    "$STAGE" || { echo "$1 isn't a Flipper.app from the official releases." >&2; exit 1; }
else
  STAGE="$HERE/build/Flipper.app"
fi

INSTALLED="/Applications/Flipper.app"

[ $# = 1 ] || ./build.sh

pin() { codesign -d -r- "$1" 2>/dev/null | sed -n 's/.*certificate leaf = H"\([0-9A-Fa-f]*\)".*/\1/p' | tr a-f A-F; }
# An ad hoc build has no certificate to pin, so its grant only fits that exact build.
signer_changed=no
if [ -d "$INSTALLED" ]; then
  new_pin=$(pin "$STAGE")
  [ -n "$new_pin" ] && [ "$(pin "$INSTALLED")" = "$new_pin" ] || signer_changed=yes
fi

pkill -x Flipper || true
for _ in $(seq 1 10); do
  pgrep -x Flipper >/dev/null || break
  sleep 0.5
done
rm -rf "$INSTALLED"
ditto "$STAGE" "$INSTALLED"

if [ "$signer_changed" = yes ]; then
  # A grant keeps the signing rule from when it was given, so an old one stops working with a new signer.
  echo "Flipper's signature changed, so its Accessibility access is reset and it asks again."
  ./uninstall.sh --permissions-only
else
  open "$INSTALLED"
fi
echo "Installed $INSTALLED and opened it. It opens at login, and asks for Accessibility if it doesn't have it yet."
