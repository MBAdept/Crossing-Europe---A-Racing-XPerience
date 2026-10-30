#!/usr/bin/env bash
# Exports the game as a single Linux x86_64 executable (PCK embedded) to build/.
# Needs Godot 4.7.2 and its export templates (~/.local/share/godot/export_templates/4.7.2.stable).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
mkdir -p build
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release "Linux" build/CrossingEurope.x86_64
chmod +x build/CrossingEurope.x86_64
ls -la build/
