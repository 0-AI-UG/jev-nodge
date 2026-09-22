#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
"$project_dir/scripts/build-app.sh"
mkdir -p "$HOME/Applications"
install_dir="$HOME/Applications/Jev Nodge.app"
# Stop only this app, including an older development instance.
while IFS= read -r app_pid; do
    [ -n "$app_pid" ] && kill -TERM "$app_pid"
done < <(pgrep -f '^.*/Jev Nodge.app/Contents/MacOS/Nodge$' || true)
if [ -d "$install_dir" ]; then
    backup_dir="$(mktemp -d "$HOME/Applications/.nodge-backup.XXXXXX")"
    mv "$install_dir" "$backup_dir/Jev Nodge.app"
    echo "Previous app preserved at $backup_dir/Jev Nodge.app"
fi
ditto "$project_dir/dist/Jev Nodge.app" "$install_dir"
# The bundle in dist is only staging output. Leaving it there makes Spotlight
# present a second, non-installed copy of the app.
rm -rf "$project_dir/dist/Jev Nodge.app"
open "$install_dir"

echo "Installed Jev Nodge in $HOME/Applications"
