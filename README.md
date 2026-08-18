# MacKards

A radial quick-launcher for macOS. Hold a hotkey to summon a circular "pie" menu around your cursor and launch pinned apps or open folders with one click.

## Features

- **Radial app launcher** — pin favorite apps in a circular menu
- **Two styles** — Cards or Ring
- **Folder actions** — Downloads, Documents, Desktop, Home, Apps, Trash, iCloud
- **Drag & drop** — move files to folders or trash via the menu
- **Customizable** — radius, card size, icon scale, gap, animation speed, hover scale
- **Configurable hotkey** — choose your own modifier combo
- **Haptic feedback** and optional Low Power mode
- **Launch at login**

## Requirements

- macOS 26+ (built for macOS Golden Gate / macOS 27 beta)
- Xcode 26 / Swift 6.2

## Build

```bash
DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer" swift build -c release
```

## Run

```bash
open build/MacKards.app
```

## How to use

1. Hold your configured hotkey (default `⌘ + ⌥`) to open the launcher at the cursor
2. Click an app to launch it
3. Click a folder action to open it in Finder
4. Drag files onto folder actions or Trash

## Author

by KRILMIW · open source
