#!/usr/bin/env bash
# Exports the game as a single Windows x86_64 executable (PCK embedded) to build/CrossingEurope.exe and
# packs it together with the licence notices (build/LIZENZEN.txt) as build/CrossingEurope-windows-x86_64.zip.
# Runs on Linux (no Windows needed). Needs Godot 4.7.2 and its export templates
# (~/.local/share/godot/export_templates/4.7.2.stable, windows_release_x86_64.exe), Python 3 and zip; the
# check of version, icon and texts of the .exe needs the Python module pefile (pip install pefile).
# Set by tools/build_release.sh: REQUIRE_PEFILE=1 (the check is mandatory), EXPECT_VERSION=0.5.0 (version
# the .exe must carry), SOURCE_DATE_EPOCH (file time in the zip). Details: docs/windows.md.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
PYTHON=${PYTHON:-python3}
EXE=build/CrossingEurope.exe
ZIP=build/CrossingEurope-windows-x86_64.zip
PEFILE=1
if ! "$PYTHON" -c "import pefile" 2>/dev/null; then
	if [ "${REQUIRE_PEFILE:-0}" = 1 ]; then
		echo "==> Python-Modul pefile fehlt (pip install pefile) – die Prüfung der .exe ist für Release-Builds Pflicht" >&2
		exit 1
	fi
	PEFILE=0
fi
mkdir -p build
rm -f "$EXE" "$ZIP" build/LIZENZEN.txt
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release "Windows Desktop" "$EXE"
if [ ! -s "$EXE" ]; then
	echo "==> Export fehlgeschlagen: $EXE fehlt" >&2
	exit 1
fi
# Godot 4.7 keeps only six of the seven icon sizes (no 24 px) and gives the icon group a broken
# name – put the complete program icon into the executable (tools/windows/set_exe_icon.py).
"$PYTHON" tools/windows/set_exe_icon.py "$EXE" assets/icons/app_icon.ico
# Check of icon, version resource (version, product name and description = game name) and embedded PCK.
VERSION=${EXPECT_VERSION:-$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)}
NAME=$(sed -n 's/^config\/name="\(.*\)"$/\1/p' project.godot)
if [ "$PEFILE" = 1 ]; then
	"$PYTHON" tools/windows/inspect_exe.py "$EXE" ${VERSION:+--version="$VERSION"} --icon-sizes=16,24,32,48,64,128,256 \
		--product="$NAME" --description="$NAME"
else
	echo "==> Hinweis: Python-Modul pefile fehlt – Prüfung von Version, Icon und Texten der .exe übersprungen (pip install pefile)" >&2
fi
# Licence notices (Godot Engine and its third-party parts, fonts, map data) – they ship with every copy.
"$GODOT" --headless --path . -s res://tools/write_licenses.gd -- "$PWD/build/LIZENZEN.txt"
if [ ! -s build/LIZENZEN.txt ]; then
	echo "==> build/LIZENZEN.txt fehlt" >&2
	exit 1
fi
# Reproducible zip: fixed permissions, file times = last commit (or SOURCE_DATE_EPOCH), no extra fields.
EPOCH=${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct 2>/dev/null || date +%s)}
chmod 644 "$EXE" build/LIZENZEN.txt
touch -d "@$EPOCH" "$EXE" build/LIZENZEN.txt
(cd build && TZ=UTC zip -q -9 -X "$(basename "$ZIP")" "$(basename "$EXE")" LIZENZEN.txt)
ls -la build/
