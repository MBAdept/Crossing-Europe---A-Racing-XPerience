#!/usr/bin/env bash
# Picture gates of v0.8.0 (docs/dev/v080_contract.md Rule 2, §4.9.3, A-6; docs/qa-v080.md).
# Arcade identity: the mode "Arcade" must draw exactly the pictures of v0.7.0 – two hash lists, both generated from
# the git tag v0.7.0 on this machine:
#   tests/golden/arcade_frames.txt → arcade_v070.md5      14 attract frames + 6 race frames with the full HUD (race
#                                                         scene, --shot-fast); MD5 of the PNG files
#   tests/golden/arcade_ui_frames.txt → arcade_ui_v070.md5  menus, a start through GameFlow, the pause menu, the
#                                                         loading picture, 1280×800; MD5 of the RGB pixels after the
#                                                         mask of the line (wall-clock arrows, version number)
# Modern change detectors: tests/golden/modern_frames.txt → modern_slice.md5, generated from THIS working copy.
#
#   tools/golden.sh make [race|ui]   exports git tag v0.7.0 into a temp folder, renders the frames with THAT game and
#                                    writes the Arcade hash list(s) (+ arcade_v070.env: Godot and OpenGL driver);
#                                    default both lists
#   tools/golden.sh check [filter]   renders both Arcade lists with this working copy (--graphics=arcade) and compares;
#                                    prints "GOLDEN arcade: N von M identisch" (race frames) and "GOLDEN arcade-ui: …";
#                                    exit code 1 unless all frames are identical. With a filter only the runs whose id
#                                    contains it.
#   tools/golden.sh modern-make      renders tests/golden/modern_frames.txt with this working copy (--graphics=modern,
#                                    no --shot-fast) and writes tests/golden/modern_slice.md5 (+ modern_slice.env)
#   tools/golden.sh modern-check [filter]   renders the Modern frames again and compares (same Godot and driver:
#                                    exact MD5 – "GOLDEN modern: N von M identisch"); then draws the frame GLES_ID once
#                                    more through OpenGL ES (--rendering-driver opengl3_es) and compares it with the
#                                    OpenGL picture of the same call: max. channel difference ≤ 2 and PSNR ≥ 60 dB
#                                    ("GOLDEN modern-gles: …"). Exit code 1 on any difference. A changed Modern picture
#                                    is not an error of the game by itself: look at the kept pictures (KEEP=<dir>), and
#                                    if the change is wanted, run modern-make and commit the list with the change.
#   tools/golden.sh list             prints the runs of all lists (id, shot times, arguments)
#   tools/golden.sh compare <dir a> <dir b>   pixel differences per frame of two kept folders (ImageMagick)
#
# Environment: GODOT (godot), GOLDEN_TAG (v0.7.0), KEEP=<dir> keeps the rendered PNGs and logs there,
# JOBS=1|2 runs in parallel (default 1 – software OpenGL already uses several cores), GLES_ID (modern_s3_hoch; empty
# = no OpenGL ES comparison).
# The hashes depend on the Godot build and the OpenGL driver (Mesa llvmpipe): after an update of either, run
# "make" again from the tag (and "modern-make") – "check" says so when the environment differs from the one of the
# hash list. Every run uses its own empty XDG_DATA_HOME (no stored settings) and one shared Mesa shader cache.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
GODOT=${GODOT:-godot}
TAG=${GOLDEN_TAG:-v0.7.0}
FRAMES="$ROOT/tests/golden/arcade_frames.txt"
LIST="$ROOT/tests/golden/arcade_v070.md5"
UI_FRAMES="$ROOT/tests/golden/arcade_ui_frames.txt"
UI_LIST="$ROOT/tests/golden/arcade_ui_v070.md5"
UI_SHOTS="tests/golden/ui_shots.gd"
ENVFILE="$ROOT/tests/golden/arcade_v070.env"
M_FRAMES="$ROOT/tests/golden/modern_frames.txt"
M_LIST="$ROOT/tests/golden/modern_slice.md5"
M_ENV="$ROOT/tests/golden/modern_slice.env"
GLES_ID=${GLES_ID-modern_s3_hoch}
JOBS=${JOBS:-1}
[ "$JOBS" -gt 2 ] 2>/dev/null && JOBS=2
MODE=${1:-}
FILTER=${2:-}

usage() {
	sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'
	exit 2
}

# Lines of a race-frame list ($1, default the Arcade list) as "id|times|args" (comments and blank lines dropped,
# fields trimmed).
frame_lines() {
	grep -vE '^\s*(#|$)' "${1:-$FRAMES}" | awk -F'|' '{ for (i = 1; i <= 3; i++) gsub(/^[ \t]+|[ \t]+$/, "", $i); print $1 "|" $2 "|" $3 }'
}

# Lines of the UI list as "id|window|time|target|args|mask".
ui_lines() {
	grep -vE '^\s*(#|$)' "$UI_FRAMES" | awk -F'|' '{ for (i = 1; i <= 6; i++) gsub(/^[ \t]+|[ \t]+$/, "", $i); print $1 "|" $2 "|" $3 "|" $4 "|" $5 "|" $6 }'
}

# Names of the PNG files the runs of a race-frame list produce (optionally only runs whose id contains $1; list $2).
expected_files() {
	frame_lines "${2:-$FRAMES}" | while IFS='|' read -r id times _; do
		if [ -n "${1:-}" ] && [[ "$id" != *"$1"* ]]; then continue; fi
		n=$(echo "$times" | tr ',' '\n' | grep -c .)
		for ((i = 0; i < n; i++)); do printf '%s_%02d.png\n' "$id" "$i"; done
	done
}

# PNG files of the UI list (one per run), optionally only runs whose id contains $1.
ui_expected_files() {
	ui_lines | while IFS='|' read -r id _; do
		if [ -n "${1:-}" ] && [[ "$id" != *"$1"* ]]; then continue; fi
		printf '%s_00.png\n' "$id"
	done
}

# render_one <project dir> <out dir> <id> <times> <args> [mode]: one run of the race scene, log in <out>/<id>.log.
# mode arcade (default): --graphics=arcade --shot-fast; modern: --graphics=modern, every frame drawn;
# modern_gles: the same through OpenGL ES.
render_one() {
	local proj=$1 out=$2 id=$3 times=$4 args=$5 mode=${6:-arcade}
	local driver=opengl3 extra="--graphics=arcade --shot-fast --gfx-sync"
	case "$mode" in
	modern) extra="--graphics=modern --gfx-sync --audio-sync" ;;
	modern_gles)
		driver=opengl3_es
		extra="--graphics=modern --gfx-sync --audio-sync"
		;;
	esac
	# shellcheck disable=SC2086
	nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path "$proj" --rendering-driver $driver \
		--audio-driver Dummy --resolution 1280x720 --fixed-fps 60 res://scenes/race/race.tscn -- \
		--screenshot="$out/$id" --shot-times="$times" $args $extra >"$out/$id.log" 2>&1
	local code=$?
	if [ $code -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed" "$out/$id.log"; then
		echo "    $id: FEHLER (Exit $code)"
		grep -E "SCRIPT ERROR|Parse Error|SHADER ERROR|^ERROR" "$out/$id.log" | head -5 | sed 's/^/      /'
		return 1
	fi
	if [ "${mode#modern}" != "$mode" ] && grep -q "Modus Modern nicht möglich" "$out/$id.log"; then
		echo "    $id: FEHLER – Modern ist auf Arcade zurückgefallen ($(grep -m1 -o "Modus Modern nicht möglich ([^)]*)" "$out/$id.log"))"
		return 1
	fi
	return 0
}

# render_all <project dir> <out dir> [filter] [list] [mode]: every run of a race-frame list, at most $JOBS at a time
render_all() {
	local proj=$1 out=$2 filter=${3:-} list=${4:-$FRAMES} mode=${5:-arcade}
	mkdir -p "$out"
	local running=0 failed=0
	while IFS='|' read -r id times args; do
		if [ -n "$filter" ] && [[ "$id" != *"$filter"* ]]; then continue; fi
		local t0=$SECONDS
		if [ "$JOBS" -le 1 ]; then
			render_one "$proj" "$out" "$id" "$times" "$args" "$mode" || failed=1
			printf '    %-20s %3d s\n' "$id" $((SECONDS - t0))
		else
			render_one "$proj" "$out" "$id" "$times" "$args" "$mode" &
			running=$((running + 1))
			if [ "$running" -ge "$JOBS" ]; then
				wait -n || failed=1
				running=$((running - 1))
			fi
		fi
	done < <(frame_lines "$list")
	while [ "$running" -gt 0 ]; do
		wait -n || failed=1
		running=$((running - 1))
	done
	return $failed
}

# render_ui_one <project dir> <out dir> <id> <window> <time> <target> <args>: one run of the UI list → <out>/<id>_00.png
render_ui_one() {
	local proj=$1 out=$2 id=$3 win=$4 time=$5 target=$6 args=$7
	local start=()
	case "$target" in
	main) start=(-- --screenshot="$out/$id" --shot-times="$time") ;;
	race) start=(res://scenes/race/race.tscn -- --screenshot="$out/$id" --shot-times="$time") ;;
	pause | loading) start=(-s "res://$UI_SHOTS" -- --shot="$target" --out="$out/${id}_00.png") ;;
	*)
		echo "    $id: unbekanntes Ziel \"$target\""
		return 1
		;;
	esac
	# own user folder per run: a menu must not see what an earlier run stored (graphics choice, records)
	local home="$out/.xdg_$id"
	rm -rf "$home"
	mkdir -p "$home"
	# shellcheck disable=SC2086
	XDG_DATA_HOME="$home" nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 ${win}x24" "$GODOT" --path "$proj" \
		--rendering-driver opengl3 --audio-driver Dummy --resolution "$win" --fixed-fps 60 "${start[@]}" $args \
		--graphics=arcade >"$out/$id.log" 2>&1
	local code=$?
	rm -rf "$home"
	if [ $code -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error" "$out/$id.log" || [ ! -s "$out/${id}_00.png" ]; then
		echo "    $id: FEHLER (Exit $code)"
		grep -E "SCRIPT ERROR|Parse Error|^ERROR" "$out/$id.log" | head -5 | sed 's/^/      /'
		return 1
	fi
	return 0
}

# render_ui_all <project dir> <out dir> [filter]: every run of the UI list, one at a time
render_ui_all() {
	local proj=$1 out=$2 filter=${3:-}
	mkdir -p "$out"
	local failed=0
	while IFS='|' read -r id win time target args mask; do
		if [ -n "$filter" ] && [[ "$id" != *"$filter"* ]]; then continue; fi
		local t0=$SECONDS
		render_ui_one "$proj" "$out" "$id" "$win" "$time" "$target" "$args" || failed=1
		printf '    %-20s %3d s\n' "$id" $((SECONDS - t0))
		: "$mask"
	done < <(ui_lines)
	return $failed
}

# ui_hash <png> <mask>: MD5 of the picture's RGB pixels after painting the mask rectangles black
ui_hash() {
	local png=$1 mask=$2
	local draw=()
	local r
	IFS=';' read -ra rects <<<"$mask"
	for r in "${rects[@]+"${rects[@]}"}"; do
		r=$(echo "$r" | tr -d ' ')
		[ -n "$r" ] || continue
		IFS=',' read -r x y w h <<<"$r"
		draw+=(-draw "rectangle $x,$y $((x + w - 1)),$((y + h - 1))")
	done
	convert "$png" -alpha off -fill black ${draw[@]+"${draw[@]}"} -depth 8 rgb:- | md5sum | cut -d' ' -f1
}

# mask_of <id>: the mask column of a UI-list run
mask_of() {
	ui_lines | awk -F'|' -v id="$1" '$1 == id { print $6 }'
}

# Godot version and OpenGL driver line of a finished run (first log of the folder).
environment_of() {
	local out=$1
	echo "godot=$("$GODOT" --version 2>/dev/null | tail -n 1)"
	echo "opengl=$(cat "$out"/*.log 2>/dev/null | grep -m1 '^OpenGL API' | sed 's/[[:space:]]*$//')"
}

# env_note <env file> <out dir>: hint when Godot or the driver differ from the ones of a hash list
env_note() {
	local envfile=$1 out=$2 how=$3
	if [ -s "$envfile" ] && ! diff -q <(grep -E '^(godot|opengl)=' "$envfile") <(environment_of "$out") >/dev/null; then
		echo "==> Hinweis: Godot oder OpenGL-Treiber sind andere als beim Erzeugen der Hash-Liste:"
		diff <(grep -E '^(godot|opengl)=' "$envfile") <(environment_of "$out") | sed 's/^/    /'
		echo "    Dann die Liste mit $how neu erzeugen."
	fi
}

# compare_race <out dir> <list> <filter>: BAD+=…, SAME, TOTAL for a race-frame list (file MD5)
compare_race() {
	local out=$1 list=$2 filter=$3 frames=$4
	SAME=0
	TOTAL=0
	for f in $(expected_files "$filter" "$frames"); do
		TOTAL=$((TOTAL + 1))
		want=$(awk -v f="$f" '$2 == f { print $1 }' "$list")
		if [ ! -s "$out/$f" ]; then
			BAD+=("$f: fehlt (nicht gerendert)")
		elif [ -z "$want" ]; then
			BAD+=("$f: kein Hash in der Liste")
		elif [ "$(md5sum < "$out/$f" | cut -d' ' -f1)" = "$want" ]; then
			SAME=$((SAME + 1))
		else
			BAD+=("$f: ANDERS")
		fi
	done
}

case "$MODE" in
list)
	echo "Arcade, Rennszene (arcade_frames.txt):"
	frame_lines | awk -F'|' '{ printf "  %-20s %-5s %s\n", $1, $2, $3 }'
	echo "  $(expected_files | wc -l) Bilder"
	echo "Arcade, Menüs/Pause/1280×800 (arcade_ui_frames.txt):"
	ui_lines | awk -F'|' '{ printf "  %-20s %-9s %-4s %-8s %s%s\n", $1, $2, $3, $4, $5, ($6 != "" ? "  [Maske " $6 "]" : "") }'
	echo "  $(ui_expected_files | wc -l) Bilder"
	echo "Modern, Änderungsmelder (modern_frames.txt):"
	frame_lines "$M_FRAMES" | awk -F'|' '{ printf "  %-20s %-5s %s\n", $1, $2, $3 }'
	echo "  $(expected_files "" "$M_FRAMES" | wc -l) Bilder"
	;;
make)
	WHICH=${2:-all}
	case "$WHICH" in
	all | race | ui) ;;
	*) usage ;;
	esac
	if ! git rev-parse -q --verify "refs/tags/$TAG^{commit}" >/dev/null; then
		echo "==> Git-Tag $TAG fehlt – die Hash-Liste entsteht aus genau diesem Stand" >&2
		exit 1
	fi
	TMP=$(mktemp -d "${TMPDIR:-/tmp}/ce_golden_make.XXXXXX")
	TMP=$(cd "$TMP" && pwd)   # absolute also with a relative TMPDIR: Godot ignores a relative XDG_DATA_HOME
	trap 'rm -rf "$TMP"' EXIT
	export XDG_DATA_HOME="$TMP/xdg" MESA_SHADER_CACHE_DIR="${MESA_SHADER_CACHE_DIR:-$TMP/mesa}"
	mkdir -p "$TMP/ref" "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
	echo "==> $TAG nach $TMP/ref exportieren"
	git archive "$TAG" | tar -x -C "$TMP/ref"
	# the imported textures of this working copy are valid for the tag as well (sprites are frozen): saves the
	# long BPTC import; everything else of .godot is rebuilt by --import
	if [ -d .godot/imported ]; then
		mkdir -p "$TMP/ref/.godot"
		cp -a .godot/imported "$TMP/ref/.godot/imported"
	fi
	# the picture helper of the UI list runs unchanged in the tag's tree
	mkdir -p "$TMP/ref/tests/golden"
	cp "$UI_SHOTS" "$TMP/ref/$UI_SHOTS"
	"$GODOT" --headless --path "$TMP/ref" --import >"$TMP/import.log" 2>&1 || true
	OUT=${KEEP:-$TMP/out}
	mkdir -p "$OUT"
	rm -f "$OUT"/*.png "$OUT"/*.log
	T0=$SECONDS
	if [ "$WHICH" != ui ]; then
		echo "==> Rennbilder mit $TAG rendern ($(expected_files | wc -l) Bilder, jedes Bild wird berechnet – einige Minuten)"
		render_all "$TMP/ref" "$OUT" || { echo "==> Rendern fehlgeschlagen – keine Hash-Liste geschrieben" >&2; exit 1; }
		MISSING=0
		for f in $(expected_files); do
			[ -s "$OUT/$f" ] || { echo "    fehlt: $f"; MISSING=1; }
		done
		[ $MISSING -eq 0 ] || { echo "==> Bilder fehlen – keine Hash-Liste geschrieben" >&2; exit 1; }
		(cd "$OUT" && md5sum $(expected_files)) > "$LIST"
		echo "==> $(wc -l < "$LIST") Hashes in ${LIST#"$ROOT"/}"
	fi
	if [ "$WHICH" != race ]; then
		echo "==> Menüs, Pause, 1280×800 mit $TAG rendern ($(ui_expected_files | wc -l) Bilder)"
		render_ui_all "$TMP/ref" "$OUT" || { echo "==> Rendern fehlgeschlagen – keine Hash-Liste geschrieben" >&2; exit 1; }
		: > "$TMP/ui.md5"
		while IFS='|' read -r id _ _ _ _ mask; do
			echo "$(ui_hash "$OUT/${id}_00.png" "$mask")  ${id}_00.png" >> "$TMP/ui.md5"
		done < <(ui_lines)
		mv "$TMP/ui.md5" "$UI_LIST"
		echo "==> $(wc -l < "$UI_LIST") Hashes in ${UI_LIST#"$ROOT"/}"
	fi
	{
		echo "tag=$TAG"
		echo "commit=$(git rev-parse "$TAG^{commit}")"
		environment_of "$OUT"
	} > "$ENVFILE"
	echo "==> fertig ($((SECONDS - T0)) s)"
	cat "$ENVFILE"
	;;
check)
	if [ ! -s "$LIST" ] || [ ! -s "$UI_LIST" ]; then
		echo "==> Hash-Liste fehlt (${LIST#"$ROOT"/}, ${UI_LIST#"$ROOT"/}) – erst tools/golden.sh make" >&2
		exit 1
	fi
	TMP=$(mktemp -d "${TMPDIR:-/tmp}/ce_golden_check.XXXXXX")
	TMP=$(cd "$TMP" && pwd)   # absolute also with a relative TMPDIR: Godot ignores a relative XDG_DATA_HOME
	trap 'rm -rf "$TMP"' EXIT
	export XDG_DATA_HOME="$TMP/xdg" MESA_SHADER_CACHE_DIR="${MESA_SHADER_CACHE_DIR:-$TMP/mesa}"
	mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
	"$GODOT" --headless --path . --import >"$TMP/import.log" 2>&1 || true
	OUT=${KEEP:-$TMP/out}
	mkdir -p "$OUT"
	rm -f "$OUT"/*.png "$OUT"/*.log
	RESULT=0
	ANY=0
	# race frames (unchanged since wave 0: "GOLDEN arcade: N von M identisch")
	if [ -n "$(expected_files "$FILTER")" ]; then
		T0=$SECONDS
		RENDER_OK=0
		render_all "$ROOT" "$OUT" "$FILTER" || RENDER_OK=1
		BAD=()
		compare_race "$OUT" "$LIST" "$FILTER" "$FRAMES"
		for b in "${BAD[@]+"${BAD[@]}"}"; do echo "    $b"; done
		ALL=$(wc -l < "$LIST")
		if [ -z "$FILTER" ] && [ "$TOTAL" -ne "$ALL" ]; then
			echo "    Hash-Liste hat $ALL Einträge, die Bildliste $TOTAL (tools/golden.sh make)"
			RENDER_OK=1
		fi
		echo "GOLDEN arcade: $SAME von $TOTAL identisch${FILTER:+ (Teilmenge \"$FILTER\")} ($((SECONDS - T0)) s)"
		ANY=$((ANY + TOTAL))
		if [ "$SAME" -ne "$TOTAL" ] || [ $RENDER_OK -ne 0 ]; then RESULT=1; fi
	fi
	# menus, GameFlow start, pause, loading picture, 1280×800 (A-6)
	if [ -n "$(ui_expected_files "$FILTER")" ]; then
		T0=$SECONDS
		RENDER_OK=0
		render_ui_all "$ROOT" "$OUT" "$FILTER" || RENDER_OK=1
		SAME=0
		TOTAL=0
		BAD=()
		while IFS='|' read -r id _ _ _ _ mask; do
			if [ -n "$FILTER" ] && [[ "$id" != *"$FILTER"* ]]; then continue; fi
			f="${id}_00.png"
			TOTAL=$((TOTAL + 1))
			want=$(awk -v f="$f" '$2 == f { print $1 }' "$UI_LIST")
			if [ ! -s "$OUT/$f" ]; then
				BAD+=("$f: fehlt (nicht gerendert)")
			elif [ -z "$want" ]; then
				BAD+=("$f: kein Hash in der Liste (tools/golden.sh make ui)")
			elif [ "$(ui_hash "$OUT/$f" "$mask")" = "$want" ]; then
				SAME=$((SAME + 1))
			else
				BAD+=("$f: ANDERS")
			fi
		done < <(ui_lines)
		for b in "${BAD[@]+"${BAD[@]}"}"; do echo "    $b"; done
		ALL=$(wc -l < "$UI_LIST")
		if [ -z "$FILTER" ] && [ "$TOTAL" -ne "$ALL" ]; then
			echo "    Hash-Liste hat $ALL Einträge, die Bildliste $TOTAL (tools/golden.sh make ui)"
			RENDER_OK=1
		fi
		echo "GOLDEN arcade-ui: $SAME von $TOTAL identisch${FILTER:+ (Teilmenge \"$FILTER\")} ($((SECONDS - T0)) s)"
		ANY=$((ANY + TOTAL))
		if [ "$SAME" -ne "$TOTAL" ] || [ $RENDER_OK -ne 0 ]; then RESULT=1; fi
	fi
	if [ "$ANY" -eq 0 ]; then
		echo "==> kein Bild passt zum Filter \"$FILTER\""
		exit 1
	fi
	if [ $RESULT -ne 0 ]; then
		env_note "$ENVFILE" "$OUT" "tools/golden.sh make (aus dem Tag)"
		echo "==> Arcade ist NICHT bildgleich mit $TAG (Bilder behalten: KEEP=<Ordner> tools/golden.sh check)"
		exit 1
	fi
	;;
modern-make | modern-check)
	if [ "$MODE" = modern-check ] && [ ! -s "$M_LIST" ]; then
		echo "==> ${M_LIST#"$ROOT"/} fehlt – erst tools/golden.sh modern-make" >&2
		exit 1
	fi
	TMP=$(mktemp -d "${TMPDIR:-/tmp}/ce_golden_modern.XXXXXX")
	TMP=$(cd "$TMP" && pwd)
	trap 'rm -rf "$TMP"' EXIT
	export XDG_DATA_HOME="$TMP/xdg" MESA_SHADER_CACHE_DIR="${MESA_SHADER_CACHE_DIR:-$TMP/mesa}"
	mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
	"$GODOT" --headless --path . --import >"$TMP/import.log" 2>&1 || true
	OUT=${KEEP:-$TMP/out}
	mkdir -p "$OUT"
	rm -f "$OUT"/*.png "$OUT"/*.log
	[ "$MODE" = modern-make ] && FILTER=""
	if [ -z "$(expected_files "$FILTER" "$M_FRAMES")" ]; then
		echo "==> kein Bild passt zum Filter \"$FILTER\""
		exit 1
	fi
	T0=$SECONDS
	echo "==> Modern-Bilder rendern ($(expected_files "$FILTER" "$M_FRAMES" | wc -l) Bilder, jedes Bild wird berechnet)"
	RENDER_OK=0
	render_all "$ROOT" "$OUT" "$FILTER" "$M_FRAMES" modern || RENDER_OK=1
	if [ "$MODE" = modern-make ]; then
		[ $RENDER_OK -eq 0 ] || { echo "==> Rendern fehlgeschlagen – keine Hash-Liste geschrieben" >&2; exit 1; }
		MISSING=0
		for f in $(expected_files "" "$M_FRAMES"); do
			[ -s "$OUT/$f" ] || { echo "    fehlt: $f"; MISSING=1; }
		done
		[ $MISSING -eq 0 ] || { echo "==> Bilder fehlen – keine Hash-Liste geschrieben" >&2; exit 1; }
		(cd "$OUT" && md5sum $(expected_files "" "$M_FRAMES")) > "$M_LIST"
		{
			echo "commit=$(git rev-parse HEAD)$( [ -n "$(git status --porcelain)" ] && echo " (Arbeitskopie geändert)")"
			environment_of "$OUT"
		} > "$M_ENV"
		echo "==> $(wc -l < "$M_LIST") Hashes in ${M_LIST#"$ROOT"/} ($((SECONDS - T0)) s)"
		cat "$M_ENV"
		exit 0
	fi
	BAD=()
	compare_race "$OUT" "$M_LIST" "$FILTER" "$M_FRAMES"
	for b in "${BAD[@]+"${BAD[@]}"}"; do echo "    $b"; done
	echo "GOLDEN modern: $SAME von $TOTAL identisch${FILTER:+ (Teilmenge \"$FILTER\")} ($((SECONDS - T0)) s)"
	RESULT=0
	if [ "$SAME" -ne "$TOTAL" ] || [ $RENDER_OK -ne 0 ]; then
		RESULT=1
		env_note "$M_ENV" "$OUT" "tools/golden.sh modern-make"
	fi
	# OpenGL ES tier (D38, §4.9.2 "the OpenGL ES path renders the same picture")
	if [ -n "$GLES_ID" ] && [ -s "$OUT/${GLES_ID}_00.png" ]; then
		line=$(frame_lines "$M_FRAMES" | awk -F'|' -v id="$GLES_ID" '$1 == id')
		times=$(echo "$line" | cut -d'|' -f2)
		args=$(echo "$line" | cut -d'|' -f3)
		T0=$SECONDS
		if render_one "$ROOT" "$OUT" "${GLES_ID}_gles" "$times" "$args" modern_gles && [ -s "$OUT/${GLES_ID}_gles_00.png" ]; then
			verdict=$(python3 -I - "$OUT/${GLES_ID}_00.png" "$OUT/${GLES_ID}_gles_00.png" <<'EOF'
import math, sys
import numpy as np
from PIL import Image
a = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(np.int32)
b = np.asarray(Image.open(sys.argv[2]).convert("RGB")).astype(np.int32)
if a.shape != b.shape:
    print("FEHLER Größe %s gegen %s" % (a.shape, b.shape))
    sys.exit(0)
d = np.abs(a - b)
mse = float((d.astype(np.float64) ** 2).mean())
psnr = 99.0 if mse == 0 else 10.0 * math.log10(255.0 ** 2 / mse)
ok = d.max() <= 2 and psnr >= 60.0
print("%s max. Abweichung %d/255, PSNR %.1f dB, %d Pixel verschieden" % ("OK" if ok else "FEHLER", d.max(), psnr, int((d.max(axis=2) > 0).sum())))
EOF
)
			echo "GOLDEN modern-gles: $GLES_ID OpenGL ES gegen OpenGL: $verdict ($((SECONDS - T0)) s)"
			case "$verdict" in OK*) ;; *) RESULT=1 ;; esac
		else
			echo "GOLDEN modern-gles: $GLES_ID über OpenGL ES nicht gerendert – FEHLER"
			grep -E "OpenGL API|ERROR" "$OUT/${GLES_ID}_gles.log" 2>/dev/null | head -3 | sed 's/^/    /'
			RESULT=1
		fi
	fi
	if [ $RESULT -ne 0 ]; then
		echo "==> Modern weicht ab (Bilder behalten: KEEP=<Ordner> tools/golden.sh modern-check; gewollt: modern-make)"
		exit 1
	fi
	;;
compare)
	A=${2:-}
	B=${3:-}
	if [ ! -d "$A" ] || [ ! -d "$B" ]; then usage; fi
	for f in $(expected_files) $(ui_expected_files) $(expected_files "" "$M_FRAMES"); do
		if [ -s "$A/$f" ] && [ -s "$B/$f" ]; then
			printf '%-24s %s Pixel verschieden\n' "$f" "$(compare -metric AE "$A/$f" "$B/$f" null: 2>&1 | awk '{ print $1 }')"
		fi
	done
	;;
*)
	usage
	;;
esac
