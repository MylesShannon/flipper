# Development

Needs a Mac with Xcode, for `swift` and the icon compiler `actool`.

| Command                          | Result                                                      |
| -------------------------------- | ----------------------------------------------------------- |
| `./build.sh`                     | Build and sign `build/Flipper.app` (git ignores `build/`)   |
| `./install.sh`                   | Build, put it in `/Applications` and open it                |
| `./install.sh path/Flipper.app`  | Install a release's app after checking its signature        |
| `./uninstall.sh`                 | Remove it, its login item and its Accessibility access      |
| `swift test`                     | Run the tests                                               |

Run the scripts as yourself, not with sudo. `uninstall.sh` takes
`--delete-settings` to remove preferences too, or `--permissions-only` to keep
Flipper installed, reset its Accessibility access and open it so it asks again.

## Layout

The decisions (which device an event came from, which directions to flip, and the
flip itself) are in `Sources/FlipperCore`, with tests in `Tests/`. The event tap is
`Sources/Flipper/ScrollTap.swift`, the menu `MenuBar.swift`, and moving to
Applications and the login item `Setup.swift`. Preferences live under the bundle
ID, `com.mylesshannon.flipper`.

## Signing

macOS grants Accessibility to an app's designated requirement. An ad hoc signature
pins that requirement to the hash of one exact build, so every rebuild looks like a
different app and has to be granted again. A certificate pins it to the bundle ID
and that certificate, which survives updates.

`build.sh` signs ad hoc unless `FLIPPER_SIGN` names a command to sign with. It's
called with the app's path and bundle ID, and for a release it must make a
Developer ID signature with the hardened runtime and a secure timestamp, which
notarization requires. For example, a script that runs:

```bash
codesign --force --options runtime --timestamp \
  --sign "Developer ID Application: <name> (<team>)" --identifier "$2" "$1"
```

`install.sh` resets Accessibility whenever the signature changes, which for ad hoc
builds is every time.

`codesign -d -r- /Applications/Flipper.app` shows what macOS checks. For a release
it's `identifier "com.mylesshannon.flipper" and anchor apple generic and
certificate leaf = H"…"`.

## Releases

Each release has `Flipper-<version>.zip`: a folder holding the signed, notarized
and stapled app with `install.sh` and `uninstall.sh`, zipped with
`ditto -c -k --keepParent`.

To publish, raise `CFBundleShortVersionString` in `Info.plist`, push main, write
the notes in a file outside the repo (or in `build/`), and run `./publish.sh
notes.md` with `FLIPPER_SIGN` set and the GitHub CLI signed in. It stops unless
main is clean and pushed and `v<version>` is a new tag. Then it builds, has Apple
notarize the app with the notarytool login saved in your Keychain (once, with
`xcrun notarytool store-credentials notary`; set `NOTARY_PROFILE` to use another
name), staples and checks it with `spctl`, zips it, pushes the tag and makes the
GitHub release with the notes and the zip.
