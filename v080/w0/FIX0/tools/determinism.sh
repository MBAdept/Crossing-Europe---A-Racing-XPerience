#!/usr/bin/env bash
# Fix-wave helper (not part of the repository): export and bake determinism of the model pipeline.
# Usage: determinism.sh <worktree> <saved cache of export 1> <md5 list of the committed assets/models> <xdg dir (absolute)>
set -uo pipefail
W=$1; RUN1=$2; COMMITTED=$3
case "${4:-}" in /*) ;; *) echo "determinism.sh: <xdg dir> muss absolut sein"; exit 2 ;; esac
export XDG_DATA_HOME=$4
mkdir -p "$XDG_DATA_HOME"
cd "$W"
echo "== 1) zwei Exporte: diff -r -x '*_report.json' <Export 1> <Export 2 (erzwungen)>"
if diff -r -x '*_report.json' "$RUN1" tools/blender/_cache3d; then echo "   leer: beide Caches byte-gleich ($(find tools/blender/_cache3d -type f | wc -l) Dateien)"; else echo "   VERSCHIEDEN"; fi
echo "== 2) Modellordner löschen, neu backen"
rm -rf assets/models/player assets/models/traffic assets/models/props assets/models/landmarks
ls assets/models
nice -n 10 godot --headless --path . -s res://tools/models/bake_models.gd 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tail -8
nice -n 10 godot --headless --path . --import 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tail -1
python3 tools/blender/export_models.py --manifest-only | tail -1
echo "== 3) git status assets/models (leer = wie eingecheckt):"
git status --short assets/models
echo "== 4) md5-Liste gegen die eingecheckten Dateien:"
(find assets/models -type f | sort | xargs md5sum) > "$XDG_DATA_HOME/assets_rebaked.md5"
if diff "$COMMITTED" "$XDG_DATA_HOME/assets_rebaked.md5" > /dev/null; then echo "   gleich: $(wc -l < "$COMMITTED") Dateien, md5 der Liste $(md5sum < "$COMMITTED" | cut -c1-32)"; else echo "   VERSCHIEDEN"; diff "$COMMITTED" "$XDG_DATA_HOME/assets_rebaked.md5" | head; fi
echo "== 5) zweiter Bake in dieselben (jetzt gefüllten) Ordner und unter Xvfb/OpenGL:"
nice -n 10 godot --headless --path . -s res://tools/models/bake_models.gd 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tail -1
git status --short assets/models
rm -rf assets/models/player assets/models/traffic assets/models/props assets/models/landmarks
nice -n 10 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy -s res://tools/models/bake_models.gd 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tail -1
nice -n 10 godot --headless --path . --import 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | tail -1
python3 tools/blender/export_models.py --manifest-only | tail -1
echo "   git status nach dem Bake unter Xvfb (leer = wie eingecheckt):"
git status --short assets/models
