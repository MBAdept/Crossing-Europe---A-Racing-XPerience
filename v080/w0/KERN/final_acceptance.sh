#!/usr/bin/env bash
# Scratch (not part of the repo): the acceptance runs of package KERN on the committed tree, one after the other.
# Usage: final_acceptance.sh <worktree> ; logs in <scratch>/final/
set -uo pipefail
PROJ=$1
W=$(cd "$(dirname "$0")" && pwd)
F="$W/final"
rm -rf "$F"
mkdir -p "$F" "$W/tmp"
cd "$PROJ"
step() { echo "=== $1 ($(date +%H:%M:%S))" | tee -a "$F/summary.txt"; }
done_step() { echo "    Exit $1, $2 s" | tee -a "$F/summary.txt"; }

step "Commit"
git rev-parse HEAD | tee -a "$F/summary.txt"
git status --short | tee -a "$F/summary.txt"

step "1 tools/run_tests.sh"
t0=$SECONDS
XDG_DATA_HOME="$F/xdg_tests" nice -n 10 tools/run_tests.sh > "$F/run_tests.log" 2>&1
done_step $? $((SECONDS - t0))
grep -E "Tests,|^CHECKS|^==>" "$F/run_tests.log" | tee -a "$F/summary.txt"

step "2 tools/golden.sh check"
t0=$SECONDS
TMPDIR="$W/tmp" KEEP="$F/golden" tools/golden.sh check > "$F/golden_check.log" 2>&1
done_step $? $((SECONDS - t0))
tail -n 2 "$F/golden_check.log" | tee -a "$F/summary.txt"

step "3 tools/run_render_checks.sh all"
t0=$SECONDS
XDG_DATA_HOME="$F/xdg_render" MESA_SHADER_CACHE_DIR="$W/mesa" tools/run_render_checks.sh all > "$F/render_checks.log" 2>&1
done_step $? $((SECONDS - t0))
grep -E "^RENDER-CHECK|^GLOW-CHECK 1|^FLIP-CHECK|^==>" "$F/render_checks.log" | cut -c1-230 | tee -a "$F/summary.txt"

step "4 run_stage.gd in beiden Modi"
for st in dev_testetappe kiel_hamburg; do
	for m in arcade modern; do
		XDG_DATA_HOME="$F/xdg_stage" nice -n 10 timeout 1200 godot --headless --path . -s res://tests/race/run_stage.gd -- --stage=$st --graphics=$m > "$F/run_${st}_$m.log" 2>&1
		echo "    $st $m: Exit $?" | tee -a "$F/summary.txt"
	done
done
python3 "$W/compare_ergebnis.py" "$F" dev_testetappe kiel_hamburg | tee -a "$F/summary.txt"

step "5 tools/build_release.sh 0.7.0"
t0=$SECONDS
mkdir -p "$F/xdg_build/godot"
ln -sfn /root/.local/share/godot/export_templates "$F/xdg_build/godot/export_templates"
XDG_DATA_HOME="$F/xdg_build" nice -n 10 tools/build_release.sh 0.7.0 > "$F/build_release.log" 2>&1
done_step $? $((SECONDS - t0))
grep -E "^Größe des Builds|^Programm|^Arcade|^UI,|^Modern|^Summe|^Archiv|^==>|^Version|^Commit:|^Archive:" "$F/build_release.log" | tee -a "$F/summary.txt"

step "6 Wine: Arcade-Bilder der neuen .exe gegen v0.7.0"
t0=$SECONDS
"$W/wine_smoke.sh" "$PROJ/build/CrossingEurope.exe" "$F/wine" neu > "$F/wine_smoke.log" 2>&1
done_step $? $((SECONDS - t0))
cat "$F/wine_smoke.log" | tee -a "$F/summary.txt"
echo "    Referenz (v0.7.0-.exe, dieselben Läufe):" | tee -a "$F/summary.txt"
(cd "$W/wine_out" && md5sum v070_*.png) | tee -a "$F/summary.txt"

step "7 Absturz-Marker über echte Programmstarts"
"$W/marker_demo.sh" "$PROJ" "$F/xdg_marker" 2>&1 | tee -a "$F/summary.txt"

step "fertig"
