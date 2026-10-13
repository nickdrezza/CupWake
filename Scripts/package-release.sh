#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"
sh Scripts/build-app.sh
app_dir="$project_dir/dist/CupWake.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_dir/Contents/Info.plist")
architecture=$(lipo -archs "$app_dir/Contents/MacOS/CupWake" | tr ' ' '-')
archive="CupWake-$version-macos-$architecture.zip"
codesign --verify --strict "$app_dir"
plutil -lint "$app_dir/Contents/Info.plist"
ditto -c -k --norsrc --noextattr --keepParent "$app_dir" "$project_dir/dist/$archive"
cd "$project_dir/dist"
shasum -a 256 "$archive" > "$archive.sha256"
printf '%s\n' "$project_dir/dist/$archive" "$project_dir/dist/$archive.sha256"
