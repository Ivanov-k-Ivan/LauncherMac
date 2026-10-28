# Launcher

A Launchpad replacement for macOS: a regular Dock app that opens a full-screen grid of every app on your Mac, with folders, search, and a configurable grid size.

Built with SwiftUI for macOS 15+.

## Build & run

1. Open `LauncherMac.xcodeproj` in Xcode.
2. Select the `LauncherMac` scheme and press ⌘R. The built app is `Launcher.app`.

The project is set up for ad-hoc signing (no developer team required) and no App Sandbox, so the app can enumerate and launch anything installed in `/Applications`, `/System/Applications`, and `~/Applications`.

If you prefer the command line:

```sh
xcodebuild -project LauncherMac.xcodeproj -scheme LauncherMac -configuration Release build
```

(If Xcode asks, accept the license first: `sudo xcodebuild -license accept`.)

## Using it

- **Open** — click the Dock icon (or launch the app), or press **⌥Space** anywhere. When the app is active you can also use **⌘⇧L**.
- **Close** — press Esc, click an app to launch it, or switch to another app.
- **Search** — start typing; Return launches the first result.
- **Pages** — swipe horizontally (or click the dots) when you have more apps than fit on one page.
- **Categories** — click a category chip below the search field to filter apps by kind; click it again to show everything.
- **Favorites** — open the **•••** menu at the top-right and choose **Edit Favorites**, then tap apps to add or remove them. Favorites are the first rows of the grid, separated from the rest by a divider, and scroll with everything else. Press Esc or Done when finished. You can also right-click any app to add/remove it.
- **Folders** — drag one app onto another to create a folder. Click a folder to open it, edit its name at the top, and drag apps out (onto the dimmed background, or use the context menu) to remove them. A folder with one app becomes a normal app again.
- **Settings** — open the **•••** menu at the top-right, or press ⌘, from the app menu.

### Settings

- **Grid** — columns (4–12) and rows (3–8); the default is 7 × 4.
- **Scrolling** — one continuous vertical grid (default), or horizontal pages with two-finger swipe / dots.
- **Presentation** — a regular resizable window (default) or a full-screen overlay (Launchpad style, hides the Dock and menu bar while open).
- **Shortcut** — enable/disable the ⌥Space global shortcut.
- **Refresh Apps / Reset Layout** — rescan installed apps, or restore the default alphabetical grid.

Layout and folders are stored in `UserDefaults` under `com.ivan.LauncherMac`.

## Project layout

```
LauncherMac/
  LauncherMacApp.swift    app entry point, Dock reopen handling
  LauncherController.swift window/overlay management, global shortcut, launch
  HotKey.swift            Carbon global hotkey wrapper
  Models/Models.swift     AppInfo, LauncherFolder, RootItem, drag payloads
  Services/AppScanner.swift
  Store/LauncherStore.swift  app list, layout, folders, persistence
  Views/                  launcher grid, folder view, settings, chrome
  Assets.xcassets         app icon and accent color
tools/make-icon.swift     regenerates the 1024pt app icon artwork (sips for sizes)
```
