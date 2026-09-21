#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
configuration="${CONFIGURATION:-debug}"
app_dir="$project_dir/dist/Nodge.app"

cd "$project_dir"
swift build -c "$configuration"
binary_dir="$(swift build -c "$configuration" --show-bin-path)"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/Nodge" "$app_dir/Contents/MacOS/Nodge"
cp "$project_dir/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/defaults.json" "$app_dir/Contents/Resources/defaults.json"
swift "$project_dir/scripts/make-icon.swift" "$app_dir/Contents/Resources/Nodge.icns"
codesign --force --deep --sign - "$app_dir"

echo "$app_dir"
