#!/usr/bin/env bash
# Scratch (wave-0 integration, not part of the repository): the geometry kernel behind the real renderer seam.
# For every case: run_stage.gd in Arcade (reference), in Modern with the stub, and in Modern with the stub plus the
# kernel (kernel_probe_renderer.gd through RaceRenderers.modern_script). The ERGEBNIS lines must be equal except gfx.
# Usage: kernel_runs.sh <project dir> <out dir>
set -uo pipefail
PROJ=$1
OUT=$2
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$OUT"
cd "$PROJ"
one() { # <id> <script> <args…>
	local id=$1 script=$2
	shift 2
	export XDG_DATA_HOME="$OUT/xdg_$id"
	mkdir -p "$XDG_DATA_HOME"
	local t0=$SECONDS
	nice -n 10 timeout 1800 godot --headless --path . -s "$script" -- "$@" > "$OUT/$id.log" 2>&1
	echo "  $id: Exit $?, $((SECONDS - t0)) s, Skriptfehler $(grep -c 'SCRIPT ERROR' "$OUT/$id.log"), ERROR-Zeilen $(grep -c '^ERROR' "$OUT/$id.log"), Marker übrig $(find "$XDG_DATA_HOME" -name modern_start.lock | wc -l)"
}
case_run() { # <name> <args…>
	local name=$1
	shift
	echo "== $name: $*"
	one "${name}_arcade" res://tests/race/run_stage.gd "$@" --graphics=arcade
	one "${name}_stub" res://tests/race/run_stage.gd "$@" --graphics=modern
	one "${name}_kernel" "$HERE/run_stage_probe.gd" "$@" --graphics=modern "--probe=$HERE/kernel_probe_renderer.gd"
}
case_run kiel_hamburg --stage=kiel_hamburg
case_run dev_nacht_regen --stage=dev_testetappe --hour=22 --weather=rain
case_run saragossa_pau_schnee --stage=saragossa_pau --from=saragossa --weather=snow
case_run sibiu_bukarest --stage=bukarest_sibiu --from=sibiu
case_run kiel_hamburg_ts4 --stage=kiel_hamburg --timescale=4
