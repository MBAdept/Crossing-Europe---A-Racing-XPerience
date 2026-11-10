#!/usr/bin/env bash
# Writes the fingerprints of the Arcade sound from a checkout of tag v0.7.0 (contract Rule 1, §6 AU-A):
#   tests/unit/audio_modern/golden/arcade_v070_headless.json   (godot --headless)
#   tests/unit/audio_modern/golden/arcade_v070_display.json    (under Xvfb: the AudioManager builds every bus)
# The tests in tests/unit/audio_modern compare the current tree against them: seeded engine mixer output, SfxSynth
# sounds, traffic model, the Arcade bus layout with all effect parameters, the hashes of the frozen audio files.
# The sample hashes are exact for one machine and engine build – regenerate after a Godot update, never to make a
# failing test pass.
# Usage: tools/audio/modern/make_arcade_golden.sh [tag]      (default v0.7.0; needs git, godot, xvfb-run)
set -euo pipefail
cd "$(dirname "$0")/../../.."
TAG=${1:-v0.7.0}
GODOT=${GODOT:-godot}
SCRIPT="$PWD/tests/unit/audio_modern/golden/arcade_golden.gd"
OUT="$PWD/tests/unit/audio_modern/golden"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/ce_arcade_golden.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/tree" "$TMP/xdg"
git archive "$TAG" | tar -x -C "$TMP/tree"
# the import cache of this checkout saves re-importing every sprite sheet (the Arcade assets are the same files)
if [ -d .godot ]; then
	cp -a .godot "$TMP/tree/"
fi
export XDG_DATA_HOME="$TMP/xdg"
export MESA_SHADER_CACHE_DIR="$TMP/mesa"
"$GODOT" --headless --path "$TMP/tree" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$TMP/tree" -s "$SCRIPT" -- "--out=$OUT/arcade_v070_headless.json" | grep arcade_golden
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path "$TMP/tree" --rendering-driver opengl3 --audio-driver Dummy \
	-s "$SCRIPT" -- "--out=$OUT/arcade_v070_display.json" | grep arcade_golden
echo "Fingerabdrücke aus $TAG geschrieben nach $OUT"
