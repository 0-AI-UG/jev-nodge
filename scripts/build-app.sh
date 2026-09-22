#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
configuration="${CONFIGURATION:-debug}"
app_dir="$project_dir/dist/Jev Nodge.app"

cd "$project_dir"
swift build -c "$configuration"
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
# SwiftPM generates executable-relative lookups. Packaged macOS apps keep
# dependency resources in Contents/Resources so Developer ID signing is valid.
for accessor in "$binary_dir"/*.build/DerivedSources/resource_bundle_accessor.swift; do
    [ -f "$accessor" ] || continue
    perl -pi -e 's/Bundle\.main\.bundleURL\.appendingPathComponent/Bundle.main.resourceURL!.appendingPathComponent/g' "$accessor"
done
swift build -c "$configuration"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/Nodge" "$app_dir/Contents/MacOS/Nodge"
cp "$project_dir/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/defaults.json" "$app_dir/Contents/Resources/defaults.json"
for resource_bundle in "$binary_dir"/*.bundle; do
    [ -d "$resource_bundle" ] || continue
    cp -R "$resource_bundle" "$app_dir/Contents/Resources/"
done
icon_renderer="$binary_dir/nodge-icon-renderer"
swiftc \
    "$project_dir/Sources/Nodge/PrismaticGlowRenderer.swift" \
    "$project_dir/scripts/IconRenderer/main.swift" \
    -o "$icon_renderer"
"$icon_renderer" \
    "$project_dir/Assets/AppIcon.png" \
    "$app_dir/Contents/Resources/Nodge.icns"
signing_identity="${NODGE_SIGNING_IDENTITY:-}"
if [ -z "$signing_identity" ]; then
    signing_identity="$(security find-identity -v -p codesigning | sed -n '/Developer ID Application:/s/.*"\(.*\)".*/\1/p' | head -n 1)"
fi
if [ -z "$signing_identity" ]; then
    echo "Set NODGE_SIGNING_IDENTITY to a persistent code-signing identity so updates retain macOS permissions." >&2
    exit 1
fi
codesign --force --deep --sign "$signing_identity" "$app_dir"

echo "$app_dir"
