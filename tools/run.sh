#!/usr/bin/env bash
# Run the game from the project root, e.g. ./tools/run.sh
set -euo pipefail
cd "$(dirname "$0")/.."
godot --path . "$@"
