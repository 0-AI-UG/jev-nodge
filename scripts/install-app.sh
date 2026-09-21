#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
"$project_dir/scripts/build-app.sh"
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Nodge.app"
cp -R "$project_dir/dist/Nodge.app" "$HOME/Applications/Nodge.app"
open "$HOME/Applications/Nodge.app"

echo "Installed Nodge in $HOME/Applications"
