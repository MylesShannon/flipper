#!/bin/bash
set -eu

[ "$(id -u)" != 0 ] || { echo "Run as yourself, not with sudo: ./build.sh"; exit 1; }
[ $# = 0 ] || { echo "Usage: ./build.sh"; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

VERSION=$(cat VERSION)
STAGE="$HERE/build/Flipper.app"

# FLIPPER_SIGN names a command that signs a release build; it's called with the app's path and bundle ID.
if [ -n "${FLIPPER_SIGN:-}" ]; then
  sign() { $FLIPPER_SIGN "$STAGE" com.mylesshannon.flipper; }
else
  sign() {
    codesign --force --sign - --identifier com.mylesshannon.flipper "$STAGE"
    echo "Signed ad hoc, so macOS asks for Accessibility again after each rebuild."
  }
fi

echo "Building Flipper..."
mkdir -p .build
if ! swift build -c release --product Flipper -Xswiftc -file-prefix-map -Xswiftc "$HERE=." > .build/swift-build.log 2>&1; then
  tail -n 30 .build/swift-build.log
  echo "Building Flipper failed."
  exit 1
fi

rm -rf "$STAGE"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/Flipper" "$STAGE/Contents/MacOS/Flipper"
# Without this, the binary keeps the paths of the folder it was built in.
strip -S -x "$STAGE/Contents/MacOS/Flipper"
sed "s/__VERSION__/$VERSION/g" Info.plist > "$STAGE/Contents/Info.plist"
# The Icon Composer icon compiles to Assets.car, which current macOS draws as a modern icon, plus AppIcon.icns for older ones.
xcrun actool Resources/AppIcon.icon --compile "$STAGE/Contents/Resources" --app-icon AppIcon --platform macosx \
  --minimum-deployment-target 14.0 --output-partial-info-plist .build/icon-partial.plist >/dev/null

sign

echo "Built build/Flipper.app."
