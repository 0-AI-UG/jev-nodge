#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
"$project_dir/scripts/build-app.sh"
open "$project_dir/dist/Nodge.app"
