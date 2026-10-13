#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"
swift build -c release --product CupWake
binary_dir=$(swift build -c release --show-bin-path)
app_dir="$project_dir/dist/CupWake.app"
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/CupWake" "$app_dir/Contents/MacOS/CupWake"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp LICENSE "$app_dir/Contents/Resources/LICENSE"
plutil -lint "$app_dir/Contents/Info.plist"
codesign --force --sign - --options runtime "$app_dir"
codesign --verify --strict "$app_dir"
printf '%s\n' "$app_dir"
