#!/usr/bin/env bash
# Arcade identity gate of v0.8.0 (docs/dev/v080_contract.md Rule 2, §4.9.3): the mode "Arcade" must draw exactly
# the pictures of v0.7.0. Renders the frames of tests/golden/arcade_frames.txt (14 attract frames + 6 race frames
# with the full HUD) under Xvfb with software OpenGL at a fixed 60 fps and compares MD5 sums of the PNG files.
#
#   tools/golden.sh make            exports git tag v0.7.0 into a temp folder, renders the frames with THAT game and
#                                   writes tests/golden/arcade_v070.md5 (+ arcade_v070.env: Godot and OpenGL driver)
#   tools/golden.sh check [filter]  renders the same frames with this working copy (--graphics=arcade --shot-fast)
#                                   and compares; prints "GOLDEN arcade: N von M identisch"; exit code 1 unless all
#                                   frames are identical. With a filter only the runs whose id contains it.
#   tools/golden.sh list            prints the runs (id, shot times, arguments)
#   tools/golden.sh compare <dir a> <dir b>   pixel differences per frame of two kept folders (ImageMagick)
#
# Environment: GODOT (godot), GOLDEN_TAG (v0.7.0), KEEP=<dir> keeps the rendered PNGs and logs there,
# JOBS=1|2 runs in parallel (default 1 – software OpenGL already uses several cores).
# The hashes depend on the Godot build and the OpenGL driver (Mesa llvmpipe): after an update of either, run
# "make" again from the tag – "check" says so when the environment differs from the one of the hash list.
# Every run uses its own empty XDG_DATA_HOME (no stored settings) and one shared Mesa shader cache.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
GODOT=${GODOT:-godot}
TAG=${GOLDEN_TAG:-v0.7.0}
FRAMES="$ROOT/tests/golden/arcade_frames.txt"
LIST="$ROOT/tests/golden/arcade_v070.md5"
ENVFILE="$ROOT/tests/golden/arcade_v070.env"
JOBS=${JOBS:-1}
[ "$JOBS" -gt 2 ] 2>/dev/null && JOBS=2
MODE=${1:-}
FILTER=${2:-}

usage() {
	sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
	exit 2
}

# Lines of the frame list as "id|times|args" (comments and blank lines dropped, fields trimmed).
frame_lines() {
	grep -vE '^\s*(#|$)' "$FRAMES" | awk -F'|' '{ for (i = 1; i <= 3; i++) gsub(/^[ \t]+|[ \t]+$/, "", $i); print $1 "|" $2 "|" $3 }'
}

# Names of the PNG files the runs produce (optionally only runs whose id contains $1), one per line.
expected_files() {
	frame_lines | while IFS='|' read -r id times _; do
		if [ -n "${1:-}" ] && [[ "$id" != *"$1"* ]]; then continue; fi
		n=$(echo "$times" | tr ',' '\n' | grep -c .)
		for ((i = 0; i < n; i++)); do printf '%s_%02d.png\n' "$id" "$i"; done
	done
}

# render_one <project dir> <out dir> <id> <times> <args>: one run of the race scene, log in <out>/<id>.log
render_one() {
	local proj=$1 out=$2 id=$3 times=$4 args=$5
	# shellcheck disable=SC2086
	nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path "$proj" --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x720 --fixed-fps 60 res://scenes/race/race.tscn -- \
		--screenshot="$out/$id" --shot-times="$times" $args --graphics=arcade --shot-fast --gfx-sync >"$out/$id.log" 2>&1
	local code=$?
	if [ $code -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error" "$out/$id.log"; then
		echo "    $id: FEHLER (Exit $code)"
		grep -E "SCRIPT ERROR|Parse Error|^ERROR" "$out/$id.log" | head -5 | sed 's/^/      /'
		return 1
	fi
	return 0
}

# render_all <project dir> <out dir> [filter]: every run of the frame list, at most $JOBS at a time
render_all() {
	local proj=$1 out=$2 filter=${3:-}
	mkdir -p "$out"
	local running=0 failed=0
	while IFS='|' read -r id times args; do
		if [ -n "$filter" ] && [[ "$id" != *"$filter"* ]]; then continue; fi
		local t0=$SECONDS
		if [ "$JOBS" -le 1 ]; then
			render_one "$proj" "$out" "$id" "$times" "$args" || failed=1
			printf '    %-10s %3d s\n' "$id" $((SECONDS - t0))
		else
			render_one "$proj" "$out" "$id" "$times" "$args" &
			running=$((running + 1))
			if [ "$running" -ge "$JOBS" ]; then
				wait -n || failed=1
				running=$((running - 1))
			fi
		fi
	done < <(frame_lines)
	while [ "$running" -gt 0 ]; do
		wait -n || failed=1
		running=$((running - 1))
	done
	return $failed
}

# Godot version and OpenGL driver line of a finished run (first log of the folder).
environment_of() {
	local out=$1
	echo "godot=$("$GODOT" --version 2>/dev/null | tail -n 1)"
	echo "opengl=$(cat "$out"/*.log 2>/dev/null | grep -m1 '^OpenGL API' | sed 's/[[:space:]]*$//')"
}

case "$MODE" in
list)
	frame_lines | awk -F'|' '{ printf "%-10s %-5s %s\n", $1, $2, $3 }'
	echo "$(expected_files | wc -l) Bilder"
	;;
make)
	if ! git rev-parse -q --verify "refs/tags/$TAG^{commit}" >/dev/null; then
		echo "==> Git-Tag $TAG fehlt – die Hash-Liste entsteht aus genau diesem Stand" >&2
		exit 1
	fi
	TMP=$(mktemp -d "${TMPDIR:-/tmp}/ce_golden_make.XXXXXX")
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
	"$GODOT" --headless --path "$TMP/ref" --import >"$TMP/import.log" 2>&1 || true
	OUT=${KEEP:-$TMP/out}
	mkdir -p "$OUT"
	rm -f "$OUT"/*.png "$OUT"/*.log
	echo "==> Bilder mit $TAG rendern ($(expected_files | wc -l) Bilder, jedes Bild wird berechnet – einige Minuten)"
	T0=$SECONDS
	render_all "$TMP/ref" "$OUT" || { echo "==> Rendern fehlgeschlagen – keine Hash-Liste geschrieben" >&2; exit 1; }
	MISSING=0
	for f in $(expected_files); do
		[ -s "$OUT/$f" ] || { echo "    fehlt: $f"; MISSING=1; }
	done
	[ $MISSING -eq 0 ] || { echo "==> Bilder fehlen – keine Hash-Liste geschrieben" >&2; exit 1; }
	(cd "$OUT" && md5sum $(expected_files)) > "$LIST"
	{
		echo "tag=$TAG"
		echo "commit=$(git rev-parse "$TAG^{commit}")"
		environment_of "$OUT"
	} > "$ENVFILE"
	echo "==> $(wc -l < "$LIST") Hashes in ${LIST#"$ROOT"/} ($((SECONDS - T0)) s)"
	cat "$ENVFILE"
	;;
check)
	if [ ! -s "$LIST" ]; then
		echo "==> ${LIST#"$ROOT"/} fehlt – erst tools/golden.sh make" >&2
		exit 1
	fi
	TMP=$(mktemp -d "${TMPDIR:-/tmp}/ce_golden_check.XXXXXX")
	trap 'rm -rf "$TMP"' EXIT
	export XDG_DATA_HOME="$TMP/xdg" MESA_SHADER_CACHE_DIR="${MESA_SHADER_CACHE_DIR:-$TMP/mesa}"
	mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
	"$GODOT" --headless --path . --import >"$TMP/import.log" 2>&1 || true
	OUT=${KEEP:-$TMP/out}
	mkdir -p "$OUT"
	rm -f "$OUT"/*.png "$OUT"/*.log
	T0=$SECONDS
	RENDER_OK=0
	render_all "$ROOT" "$OUT" "$FILTER" || RENDER_OK=1
	SAME=0
	TOTAL=0
	BAD=()
	for f in $(expected_files "$FILTER"); do
		TOTAL=$((TOTAL + 1))
		want=$(awk -v f="$f" '$2 == f { print $1 }' "$LIST")
		if [ ! -s "$OUT/$f" ]; then
			BAD+=("$f: fehlt (nicht gerendert)")
		elif [ -z "$want" ]; then
			BAD+=("$f: kein Hash in der Liste (tools/golden.sh make)")
		elif [ "$(md5sum < "$OUT/$f" | cut -d' ' -f1)" = "$want" ]; then
			SAME=$((SAME + 1))
		else
			BAD+=("$f: ANDERS")
		fi
	done
	for b in "${BAD[@]+"${BAD[@]}"}"; do echo "    $b"; done
	ALL=$(wc -l < "$LIST")
	if [ -z "$FILTER" ] && [ "$TOTAL" -ne "$ALL" ]; then
		echo "    Hash-Liste hat $ALL Einträge, die Bildliste $TOTAL (tools/golden.sh make)"
		RENDER_OK=1
	fi
	echo "GOLDEN arcade: $SAME von $TOTAL identisch${FILTER:+ (Teilmenge \"$FILTER\")} ($((SECONDS - T0)) s)"
	if [ "$SAME" -ne "$TOTAL" ] || [ "$TOTAL" -eq 0 ] || [ $RENDER_OK -ne 0 ]; then
		if [ -s "$ENVFILE" ] && ! diff -q <(grep -E '^(godot|opengl)=' "$ENVFILE") <(environment_of "$OUT") >/dev/null; then
			echo "==> Hinweis: Godot oder OpenGL-Treiber sind andere als beim Erzeugen der Hash-Liste:"
			diff <(grep -E '^(godot|opengl)=' "$ENVFILE") <(environment_of "$OUT") | sed 's/^/    /'
			echo "    Dann die Liste mit tools/golden.sh make neu aus dem Tag erzeugen."
		fi
		echo "==> Arcade ist NICHT bildgleich mit $TAG (Bilder behalten: KEEP=<Ordner> tools/golden.sh check)"
		exit 1
	fi
	;;
compare)
	A=${2:-}
	B=${3:-}
	if [ ! -d "$A" ] || [ ! -d "$B" ]; then usage; fi
	for f in $(expected_files); do
		if [ -s "$A/$f" ] && [ -s "$B/$f" ]; then
			printf '%-18s %s Pixel verschieden\n' "$f" "$(compare -metric AE "$A/$f" "$B/$f" null: 2>&1 | awk '{ print $1 }')"
		fi
	done
	;;
*)
	usage
	;;
esac
