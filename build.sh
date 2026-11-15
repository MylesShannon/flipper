#!/bin/bash
set -eu
trap 'echo "build.sh stopped at line $LINENO. The output above says why." >&2' ERR
[ "$(id -u)" != 0 ] || { echo "Run as yourself, not with sudo: ./build.sh" >&2; exit 1; }
[ $# = 0 ] || { echo "Usage: ./build.sh" >&2; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

ID=com.mylesshannon.flipper
VERSION=$(cat VERSION)
STAGE="$HERE/build/Flipper.app"
FRAMEWORK="$STAGE/Contents/Frameworks/Sparkle.framework"

# FLIPPER_SIGN names a command that signs a release build; it's called with a path, its identifier, and for code that
# needs them, --entitlements and a file. Without it, builds are signed ad hoc, and without the hardened runtime, whose
# library validation would refuse Sparkle for having a different Team ID than an ad hoc app's none.
if [ -n "${FLIPPER_SIGN:-}" ]; then
  sign() { $FLIPPER_SIGN "$@"; }
else
  sign() {
    local target=$1 identifier=$2
    shift 2
    codesign --force --sign - --identifier "$identifier" "$@" "$target"
  }
fi

echo "Building Flipper $VERSION..."
mkdir -p .build
rm -f .build/install_name_tool.log
slice() {
  if ! swift build -c release --arch "$1" --scratch-path ".build-$1" --product Flipper \
    -Xswiftc -file-prefix-map -Xswiftc "$HERE=." > .build/swift-build.log 2>&1; then
    tail -n 30 .build/swift-build.log >&2
    echo "Building Flipper failed." >&2
    exit 1
  fi
  swift build -c release --arch "$1" --scratch-path ".build-$1" --show-bin-path
}
ARM=$(slice arm64)
INTEL=$(slice x86_64)

rm -rf "$STAGE"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources" "$STAGE/Contents/Frameworks"
lipo -create -output "$STAGE/Contents/MacOS/Flipper" "$ARM/Flipper" "$INTEL/Flipper"
# Without this, the binary keeps the paths of the folder it was built in.
strip -S -x "$STAGE/Contents/MacOS/Flipper"
# SwiftPM links Sparkle as @rpath, and the binary's own rpaths don't include Contents/Frameworks.
cp -R "$ARM/Sparkle.framework" "$STAGE/Contents/Frameworks/"
if ! install_name_tool -add_rpath "@executable_path/../Frameworks" "$STAGE/Contents/MacOS/Flipper" > .build/install_name_tool.log 2>&1; then
  tail -n 30 .build/install_name_tool.log >&2
  echo "Adding the Frameworks folder to Flipper's search path failed, so Flipper wasn't built." >&2
  exit 1
fi
sed "s/__VERSION__/$VERSION/g" Info.plist > "$STAGE/Contents/Info.plist"
# The Icon Composer icon compiles to Assets.car, which current macOS draws as a modern icon, plus AppIcon.icns for older ones.
if ! xcrun actool "$HERE/Resources/AppIcon.icon" --compile "$STAGE/Contents/Resources" --app-icon AppIcon --platform macosx \
  --minimum-deployment-target 15.0 --output-partial-info-plist "$HERE/.build/icon-partial.plist" > .build/actool.log 2>&1 ||
  [ ! -f "$STAGE/Contents/Resources/Assets.car" ]; then
  tail -n 30 .build/actool.log >&2
  echo "Building the icon failed, so Flipper wasn't built." >&2
  exit 1
fi

case ${FLIPPER_SIGN:-} in sudo\ *) echo "Signing needs your password." ;; esac
# Inside out, because the outer signature is only valid once the code inside it is settled. Sparkle's parts keep the
# identifiers and entitlements Sparkle gave them.
for nested in XPCServices/Downloader.xpc XPCServices/Installer.xpc Updater.app Autoupdate ""; do
  path="$FRAMEWORK/Versions/B/$nested"
  [ -e "$path" ] || continue
  identifier=$(codesign -dv "$path" 2>&1 | sed -n 's/^Identifier=//p')
  entitlements="build/$(basename "$path").entitlements"
  codesign -d --entitlements - --xml "$path" > "$entitlements" 2>/dev/null || true
  if [ -s "$entitlements" ]; then
    sign "$path" "$identifier" --entitlements "$entitlements"
  else
    sign "$path" "$identifier"
  fi
  rm -f "$entitlements"
done
sign "$STAGE" "$ID"
codesign --verify --deep --strict "$STAGE"

if [ -n "${FLIPPER_SIGN:-}" ]; then
  echo "Built and signed build/Flipper.app."
else
  echo "Built build/Flipper.app, signed ad hoc, so macOS asks for its permissions again after each rebuild."
fi
