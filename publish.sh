#!/bin/bash
set -eu
trap 'echo "publish.sh stopped at line $LINENO. The output above says why." >&2' ERR
[ "$(id -u)" != 0 ] || { echo "Run as yourself, not with sudo: ./publish.sh <notes.md>" >&2; exit 1; }
[ $# = 1 ] || { echo "Usage: ./publish.sh <notes.md>" >&2; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"

case $1 in /*) NOTES=$1 ;; *) NOTES=$OLDPWD/$1 ;; esac
[ -f "$NOTES" ] || { echo "$1 isn't a file." >&2; exit 1; }
NOTARY_PROFILE=${NOTARY_PROFILE:-notary}

[ -n "${FLIPPER_SIGN:-}" ] || { echo "Set FLIPPER_SIGN to the command that signs release builds. See docs/development.md." >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Sign in to GitHub first: gh auth login" >&2; exit 1; }
[ "$(git branch --show-current)" = main ] || { echo "Switch to main first." >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Commit or remove your changes first. Keep the notes outside the repo or in build/." >&2; exit 1; }

VERSION=$(cat VERSION)
TAG="v$VERSION"
NAME="Flipper-$VERSION"

git fetch --quiet origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "Push main first, so the release matches GitHub." >&2; exit 1; }
if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null; then
  echo "$TAG is already on GitHub. Raise VERSION for a new release." >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

./build.sh

APP="$work/$NAME/Flipper.app"
mkdir "$work/$NAME"
ditto "build/Flipper.app" "$APP"
if codesign -dv "$APP" 2>&1 | grep -q 'Signature=adhoc'; then
  echo "build/Flipper.app is signed ad hoc, which Apple won't notarize. Check FLIPPER_SIGN." >&2
  exit 1
fi

echo "Notarizing Flipper $VERSION with Apple..."
ditto -c -k --keepParent "$APP" "$work/notarize.zip"
out=$(xcrun notarytool submit "$work/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json) || {
  echo "Notarizing didn't finish. If notarytool has no saved login yet, add one with: xcrun notarytool store-credentials $NOTARY_PROFILE" >&2
  exit 1
}
[ "$(jq -r .status <<<"$out")" = Accepted ] || {
  echo "Apple didn't accept Flipper. See why with: xcrun notarytool log $(jq -r .id <<<"$out") --keychain-profile $NOTARY_PROFILE" >&2
  exit 1
}
xcrun stapler staple -q "$APP"
spctl --assess --type execute "$APP"

cp install.sh uninstall.sh "$work/$NAME/"
ZIP="$HERE/build/$NAME.zip"
rm -f "$ZIP"
(cd "$work" && ditto -c -k --keepParent "$NAME" "$ZIP")

git tag -a "$TAG" -m "Flipper $VERSION"
git push --quiet origin "$TAG"

echo "Creating the $TAG release..."
if ! gh release create "$TAG" "$ZIP" --verify-tag --title "Flipper $VERSION" --notes-file "$NOTES" --latest; then
  echo "$TAG is pushed but the release wasn't made. Make it from that tag on GitHub and upload build/$NAME.zip." >&2
  exit 1
fi
echo "Published Flipper $VERSION."
