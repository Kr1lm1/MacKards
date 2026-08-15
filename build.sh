#!/bin/bash
set -e
cd "$(dirname "$0")"

[ -d "/Applications/Xcode.app" ] && export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
[ -d "/Applications/Xcode-beta.app" ] && export DEVELOPER_DIR="/Applications/Xcode-beta.app/Contents/Developer"

echo "Building MacKards..."
swift build -c release 2>&1

mkdir -p build/MacKards.app/Contents/MacOS
cp .build/release/MacKards build/MacKards.app/Contents/MacOS/MacKards
cp MacKards/Info.plist build/MacKards.app/Contents/Info.plist

echo "Done: build/MacKards.app"
echo "Hotkey: Hold ⌘⌥"

[ "$1" = "--run" ] && open build/MacKards.app
