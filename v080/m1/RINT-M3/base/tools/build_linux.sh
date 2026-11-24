#!/usr/bin/env bash
# Exports the game as a single Linux x86_64 executable (PCK embedded) to build/ and prints the size table of the
# build (tools/pck_report.py: megabytes per part of the size budget; fails above 330 MB of estimated archive size).
# Needs Godot 4.7.2 and its export templates (~/.local/share/godot/export_templates/4.7.2.stable), Python 3.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
PYTHON=${PYTHON:-python3}
mkdir -p build
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release "Linux" build/CrossingEurope.x86_64
chmod +x build/CrossingEurope.x86_64
ls -la build/
"$PYTHON" tools/pck_report.py build/CrossingEurope.x86_64
