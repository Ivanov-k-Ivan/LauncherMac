<p align="center">
  <a href="https://buymeacoffee.com/mavasilisk">
    <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee" height="46">
  </a>
</p>

<h1 align="center">Launcher</h1>

<p align="center"><strong>A fast, free replacement for macOS Launchpad.</strong></p>

<p align="center">Launcher shows every app on your Mac in a clean, keyboard-friendly grid. Search instantly, organise apps into folders, pin your favourites, and filter by category — all without leaving the keyboard.</p>

<p align="center">
  <a href="#requirements"><img src="https://img.shields.io/badge/macOS-15.0%2B-black?logo=apple" alt="macOS 15+"></a>
  <a href="LauncherMac"><img src="https://img.shields.io/badge/SwiftUI-Swift-orange?logo=swift" alt="Built with SwiftUI"></a>
</p>

---

## Features

- **Every app, one grid** — scans `/Applications`, `/System/Applications`, and `~/Applications` automatically, and picks up newly installed apps on its own.
- **Instant search** — start typing and press Return to launch the first match.
- **Favourites** — pin the apps you use most; they sit in their own row above the rest of the grid.
- **Folders** — drag one app onto another to create a folder, rename it, and drag apps in or out.
- **Categories** — filter by Developer Tools, Utilities, Productivity & Finance, Creativity, Social, Entertainment, and Information & Reading.
- **Your layout, remembered** — reorder apps and folders; everything is saved between launches.
- **Two looks** — a resizable Spotlight-style window, or a full-screen Launchpad-style overlay that hides the Dock and menu bar.
- **Lives out of the way** — no Dock icon. Open it with a global shortcut and get straight back to work.
- **Private by design** — no accounts, no telemetry, no network access. Your layout never leaves your Mac.

## Requirements

- macOS 15 (Sequoia) or later.
- Apple silicon or Intel Mac.

## Install

### Download

Grab the latest `Launcher.app` from the [Releases](../../releases) page, then drag it into your **Applications** folder.

Launcher is ad-hoc signed rather than notarised, so the first time you open it macOS may warn you. To bypass the warning:

1. In **Finder**, right-click **Launcher** and choose **Open**, then confirm **Open**.
2. Or run:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Launcher.app
   ```

### Build from source

Requires Xcode 16 or later.

```sh
git clone https://github.com/Ivanov-k-Ivan/LauncherMac.git
cd LauncherMac

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project LauncherMac.xcodeproj -scheme LauncherMac \
  -configuration Release -derivedDataPath .build build

cp -R .build/Build/Products/Release/Launcher.app /Applications/
open /Applications/Launcher.app
```

You can also open `LauncherMac.xcodeproj` in Xcode, select the **LauncherMac** scheme, and press ⌘R.

## Using Launcher

Launcher opens automatically when you launch it. After that, bring it back any time:

| Action | Shortcut |
| --- | --- |
| Show / hide Launcher | **⌥Space** |
| Show Launcher (while Launcher is active) | **⌘⇧L** |
| Launch the first search result | **Return** |
| Close Launcher or a folder | **Esc** |
| Open Settings | **⌘,** |
| Quit Launcher | **⌘Q** |

- **Launch an app** — click it, or search and press Return. Launcher closes itself afterwards.
- **Search** — just start typing. Matching apps appear instantly.
- **Change pages** — swipe with two fingers or click the page dots (in horizontal layout).
- **Filter by category** — click a category chip; click it again to show everything.
- **Favourites** — open the **•••** menu, choose **Edit Favorites**, then click apps to add or remove them. Right-clicking any app works too.
- **Folders** — drag an app onto another app. Click the folder to open it; drag apps out to the dimmed background (or use the context menu) to remove them.
- **Rearrange** — drag apps and folders anywhere in the grid.

## Settings

Open **••• → Settings…** or press **⌘,**

- **Grid** — choose 4–12 columns and 3–8 rows (default 7 × 4).
- **Scrolling** — one continuous vertical grid (default), or horizontal pages.
- **Presentation** — a regular resizable window (default) or full-screen overlay.
- **Shortcut** — enable or disable the ⌥Space global shortcut.
- **Refresh Apps** — rescan installed applications.
- **Reset Layout** — restore the default alphabetical grid.
- **Reset to Default** — restore every setting and reset your layout.

## How it works

Launcher is a native SwiftUI app. It reads the list of installed apps from the standard application folders and keeps your layout in `UserDefaults`. It does not use the network, does not require an account, and does not collect analytics.

Because it is not sandboxed, it can enumerate and launch anything under the paths above. The source is small and easy to audit — see [`LauncherMac/`](LauncherMac) if you'd like to look around.

## Troubleshooting

**Launcher doesn't appear when I press ⌥Space.**
Another app may already be using that shortcut. Open Settings and toggle the global shortcut off and on, or quit the conflicting app.

**An app is missing from the grid.**
Open Settings and click **Refresh Apps**. Only apps inside `/Applications`, `/System/Applications`, and `~/Applications` are listed; apps elsewhere are not scanned.

**The window opened off-screen.**
Open Settings and use **Reset Layout**, or click **Reset to Default** to restore the window position and size.

**macOS says the app is damaged or can't be opened.**
See the [Install](#install) section above to clear the quarantine flag.

## Contributing

Issues and pull requests are welcome. If you spot a bug or have an idea, open an issue with your macOS version and a short description of what happened.

If you'd like to contribute code:

1. Fork the repo and create a branch.
2. Keep changes focused and match the existing Swift/SwiftUI style.
3. Build and test locally with the commands above.
4. Open a pull request describing the change.

## Support

Launcher is free and always will be. If it saves you a little time each day, you can say thanks with a coffee:

<a href="https://buymeacoffee.com/mavasilisk"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee" height="48"></a>

## License

Launcher is **free to use, copy, modify, and share** for personal and other non-commercial purposes — no payment, account, or sign-up required.

The only conditions:

- **Credit the author.** If you share Launcher or a modified version, mention **Ivan Ivanov** and link back to [this repository](https://github.com/Ivanov-k-Ivan/LauncherMac).
- **No commercial use.** You may not sell Launcher, bundle it into a paid product, or otherwise use it to make money.

See [LICENSE](LICENSE) for the full terms.
