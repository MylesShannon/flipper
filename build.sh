#!/bin/bash
set -eu
trap 'echo "build.sh stopped at line $LINENO. The output above says why." >&2' ERR
[ "$(id -u)" != 0 ] || { echo "Run as yourself, not with sudo: ./build.sh" >&2; exit 1; }
[ $# = 0 ] || { echo "Usage: ./build.sh" >&2; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

VERSION=$(cat VERSION)
STAGE="$HERE/build/Flipper.app"

echo "Building Flipper $VERSION..."
mkdir -p .build
if ! swift build -c release --product Flipper -Xswiftc -file-prefix-map -Xswiftc "$HERE=." > .build/swift-build.log 2>&1; then
  tail -n 30 .build/swift-build.log >&2
  echo "Building Flipper failed." >&2
  exit 1
fi

rm -rf "$STAGE"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/Flipper" "$STAGE/Contents/MacOS/Flipper"
# Without this, the binary keeps the paths of the folder it was built in.
strip -S -x "$STAGE/Contents/MacOS/Flipper"
sed "s/__VERSION__/$VERSION/g" Info.plist > "$STAGE/Contents/Info.plist"
# The Icon Composer icon compiles to Assets.car, which current macOS draws as a modern icon, plus AppIcon.icns for older ones.
if ! xcrun actool Resources/AppIcon.icon --compile "$STAGE/Contents/Resources" --app-icon AppIcon --platform macosx \
  --minimum-deployment-target 14.0 --output-partial-info-plist .build/icon-partial.plist > .build/actool.log 2>&1; then
  tail -n 30 .build/actool.log >&2
  echo "Compiling Flipper's icon with actool failed." >&2
  exit 1
fi

# FLIPPER_SIGN names a command that signs a release build; it's called with the app's path and bundle ID.
if [ -n "${FLIPPER_SIGN:-}" ]; then
  case $FLIPPER_SIGN in sudo\ *) echo "Signing needs your password." ;; esac
  $FLIPPER_SIGN "$STAGE" com.mylesshannon.flipper
  echo "Built and signed build/Flipper.app."
else
  codesign --force --sign - --identifier com.mylesshannon.flipper "$STAGE"
  echo "Built build/Flipper.app, signed ad hoc, so macOS asks for its permissions again after each rebuild."
fi
