# Development

Needs a Mac running macOS 15 or later with Xcode, for `swift` and the icon compiler
`actool`.

| Command                          | Result                                                      |
| -------------------------------- | ----------------------------------------------------------- |
| `./build.sh`                     | Build and sign `build/Flipper.app` (git ignores `build/`)   |
| `./install.sh`                   | Build, put it in `/Applications` and open it                |
| `./install.sh path/Flipper.app`  | Install a release's app after checking its signature        |
| `./uninstall.sh`                 | Remove it, its login item and its Accessibility access      |
| `./publish.sh notes.md`          | Test, build, notarize and publish a release                 |
| `swift test`                     | Run the tests                                               |

Run the scripts as yourself, not with sudo. `uninstall.sh` takes
`--delete-settings` to remove preferences too, or `--permissions-only` to keep
Flipper installed, reset its Accessibility access and open it so it asks again.

## Layout

The decisions (which device an event came from, which directions to flip, and the
flip itself) are in `Sources/FlipperCore`, with tests in `Tests/`. The event tap is
`Sources/Flipper/ScrollTap.swift`, the menu and the updater `MenuBar.swift`, and
moving to Applications and the login item `Setup.swift`. Preferences live under the
bundle ID, `com.mylesshannon.flipper`.

## Signing

macOS grants Accessibility to an app's designated requirement. An ad hoc signature
pins that requirement to the hash of one exact build, so every rebuild looks like a
different app and has to be granted again. A certificate pins it to the bundle ID
and that certificate, which survives updates.

`build.sh` signs ad hoc unless `FLIPPER_SIGN` names a command to sign with. It's
called with a path and its identifier, followed by `--entitlements <file>` for code
that has entitlements, and for a release it must make a Developer ID signature with
the hardened runtime and a secure timestamp, which notarization requires. For
example, a script that runs:

```bash
path=$1 identifier=$2
shift 2
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: <name> (<team>)" --identifier "$identifier" "$@" "$path"
```

Sparkle's XPC services, `Updater.app`, `Autoupdate` and framework are signed from
the inside out before the app itself, each keeping the identifier and entitlements
Sparkle gave it.

Ad hoc builds leave the hardened runtime off. It turns on library validation, which
requires embedded frameworks to carry the same Team ID as the app, and an ad hoc
signature has none, so Sparkle would fail to load and the app wouldn't start.

`install.sh` resets Accessibility whenever the signature changes, which for ad hoc
builds is every time.

`codesign -d -r- /Applications/Flipper.app` shows what macOS checks. For a release
it's `identifier "com.mylesshannon.flipper" and anchor apple generic and
certificate leaf = H"…"`.

## Tests

`swift test` runs the tests in `Tests/`, which cover how events are told apart,
which directions get flipped, and saving the settings. `publish.sh` runs them
before every release and stops if any fail.

## Version numbers

The version is in `VERSION`, and `build.sh` writes it into both
`CFBundleShortVersionString` and `CFBundleVersion` of the app it builds. There's no
separate build number, because Sparkle compares the version as it is.

## Updates

Sparkle handles updates: it reads `docs/appcast.xml`, which GitHub Pages serves
from main, compares versions, shows its own dialog, downloads, verifies, installs
and relaunches. `Info.plist` carries `SUFeedURL`, `SUPublicEDKey`, and
`SUEnableAutomaticChecks`, which switches on **Check for Updates Automatically**
until the user turns it off. Sparkle keeps that choice in Flipper's preferences.
Flipper starts Sparkle only from Applications, and also checks quietly a few
seconds after it opens.

The private half of the key pair lives in the login keychain of the Mac that
publishes, made once with Sparkle's `generate_keys --account flipper`. After a
build has downloaded Sparkle, that's
`.build/artifacts/sparkle/Sparkle/bin/generate_keys --account flipper`, which
prints the public key for `SUPublicEDKey`. **Back it up.** Without it no future
release can be signed, and installs already out there have no way to update. Until
`Info.plist` has the key instead of `__SPARKLE_PUBLIC_KEY__`, `build.sh` refuses to
make a signed build, and Sparkle in an ad hoc build reports that it can't start.

`publish.sh` exports the key with `generate_keys -x` into its temporary folder and
passes it to `generate_appcast` with `--ed-key-file`, because over SSH
`generate_appcast` can't show the dialog that asks for the keychain.

Release notes for the update dialog live in `docs/release-notes/<version>.html`:
`<h2>Flipper <version></h2>`, a `<p>` with a one-line summary, then a `<ul>` with
what changed. Note that `generate_appcast` only rewrites an entry when the DMG's
bytes change, so editing notes for an already-signed version means removing its
item from `docs/appcast.xml` and regenerating.

`Package.resolved` is committed so Sparkle's version is pinned.

## Releases

Each release has `Flipper-<version>.dmg`: the signed, notarized and stapled app
with an Applications link to drag it onto.

To publish, raise `VERSION`, write and commit `docs/release-notes/<version>.html`,
push main, write the GitHub release notes in a file outside the repo (or in
`build/`), and run `./publish.sh notes.md` with `FLIPPER_SIGN` set and the GitHub
CLI signed in (`gh auth login` once). It stops unless main is clean and pushed and
`v<version>` is a new tag. Then it runs the tests, builds, has Apple notarize the
app with the notarytool login saved in your Keychain (once, with
`xcrun notarytool store-credentials notary`; set `NOTARY_PROFILE` to use another
name), staples and checks it with `spctl`, and makes the DMG. It signs the appcast
with the Sparkle key and checks that the appcast states the DMG's exact size,
because a mismatch there stays invisible until an update fails to install. Finally
it commits the appcast to main as `chore: appcast for v<version>`, pushes that
commit and the tag together, and makes the GitHub release with the notes and the
DMG. Pages then serves the new appcast, and Sparkle offers the update.
