#!/usr/bin/env bash
# Exports the game as a single Windows x86_64 executable (PCK embedded) to build/CrossingEurope.exe and
# packs it as build/CrossingEurope-windows-x86_64.zip. Runs on Linux (no Windows needed).
# Needs Godot 4.7.2 and its export templates (~/.local/share/godot/export_templates/4.7.2.stable,
# windows_release_x86_64.exe), Python 3 and zip. Details: docs/windows.md.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
PYTHON=${PYTHON:-python3}
EXE=build/CrossingEurope.exe
ZIP=build/CrossingEurope-windows-x86_64.zip
mkdir -p build
rm -f "$EXE" "$ZIP"
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release "Windows Desktop" "$EXE"
if [ ! -s "$EXE" ]; then
	echo "==> Export fehlgeschlagen: $EXE fehlt" >&2
	exit 1
fi
# Godot 4.7 keeps only six of the seven icon sizes (no 24 px) and gives the icon group a broken
# name – put the complete program icon into the executable (tools/windows/set_exe_icon.py).
"$PYTHON" tools/windows/set_exe_icon.py "$EXE" assets/icons/app_icon.ico
# Optional check of icon, version resource and embedded PCK (needs the Python module pefile).
if "$PYTHON" -c "import pefile" 2>/dev/null; then
	VERSION=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)
	"$PYTHON" tools/windows/inspect_exe.py "$EXE" ${VERSION:+--version="$VERSION"} --icon-sizes=16,24,32,48,64,128,256
fi
(cd build && zip -q -9 -X "$(basename "$ZIP")" "$(basename "$EXE")")
ls -la build/
