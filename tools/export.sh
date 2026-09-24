#!/usr/bin/env bash
# Export a build using a preset defined in export_presets.cfg.
# Usage: ./tools/export.sh "<preset name>" builds/kyykka
#
# Export presets are not included in this scaffold — create them once via
# the editor (Project > Export...) and pick "release" export there, which
# writes export_presets.cfg. Export templates matching the installed Godot
# version must also be installed (Editor > Manage Export Templates).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -ne 2 ]; then
	echo "Usage: $0 <preset name> <output path>" >&2
	exit 1
fi

mkdir -p "$(dirname "$2")"
godot --headless --path . --export-release "$1" "$2"
