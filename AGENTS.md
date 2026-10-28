# AGENTS.md

## Build and install

Always build, then overwrite the installed app at `/Applications/Launcher.app`. Do not leave a stale copy behind, and do not install anywhere else.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project LauncherMac.xcodeproj -scheme LauncherMac \
  -configuration Release -derivedDataPath .build build
```

The product is `.build/Build/Products/Release/Launcher.app`.

Then quit the running copy and replace it:

```sh
osascript -e 'quit app "Launcher"' 2>/dev/null
sleep 1
rm -rf /Applications/Launcher.app
cp -R .build/Build/Products/Release/Launcher.app /Applications/Launcher.app
open /Applications/Launcher.app
```

## Notes

- `xcode-select` points at the Command Line Tools, so `xcodebuild` only works with the `DEVELOPER_DIR` prefix above.
- If `xcodebuild` reports that the Xcode license has not been agreed to, the one-time fix (needs the user's password) is:
  `sudo --preserve-env=DEVELOPER_DIR xcodebuild -license accept`
- Quick syntax check without a full build: `swiftc -parse LauncherMac/<File>.swift`
- The project uses ad-hoc signing and has no sandbox, so it can enumerate and launch apps under `/Applications`, `/System/Applications`, and `~/Applications`.
