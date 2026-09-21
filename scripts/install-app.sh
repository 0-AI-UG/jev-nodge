#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
"$project_dir/scripts/build-app.sh"
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Jev Nodge.app"
cp -R "$project_dir/dist/Jev Nodge.app" "$HOME/Applications/Jev Nodge.app"
open "$HOME/Applications/Jev Nodge.app"

echo "Installed Jev Nodge in $HOME/Applications"
