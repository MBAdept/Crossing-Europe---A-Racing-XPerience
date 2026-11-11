#!/usr/bin/env bash
# A/B sheets of the reference positions (v0.8.0, docs/dev/v080_contract.md §4.9.2, docs/qa-v080.md): for every
# position and quality preset one Arcade | Modern picture of the SAME simulation state (tools/ab_shot.sh), plus one
# overview sheet per preset with all positions – the picture package of a gate (§7).
#
#   tools/ab_sheet.sh <out_dir> [position …]
#
# Positions (default: all of them, in this order):
#   S1–S5  Kiel – Hamburg km 2 / 13.6 (first fuel lane) / 60 / 80 (City Limits, 50 km/h) / 94 (finish), 12:00
#   T1, T2 Kassel – Würzburg km 46.5 (bend into a descent) / 61.9 (crest), 15:00
#   T3, T4 Saragossa – Pau km 172.8 (climbing bend) / 198.8 (R ≈ 136 m), 11:00
#   N1     Hamburg – Hannover km 71, snow, 22:00         N2  Dortmund – Frankfurt km 121, rain, 16:00
#   C1     Dortmund – Frankfurt km 221, 19:30 (City Limits, rush hour)
#   U1     Bern – Mailand km 186 (Gotthard tunnel), 12:00      DEV  dev_testetappe km 48, 21:00
# Every position is a flying start with the autopilot (it never refuels), traffic warmed up, no countdown; seeds
# and vehicles as in the Arcade goldens (tests/golden/arcade_frames.txt). Arguments after "--" are added to every
# position (a later argument wins), e.g. --shot-times=2,6.
#
# Output per position P and preset Q (Q = the preset name, "auto" = the preset this machine picks by itself):
#   <out_dir>/<P>_<Q>_ab_NN.jpg          Arcade | Modern side by side (+ the two PNGs and the logs of tools/ab_shot.sh)
#   <out_dir>/uebersicht_<Q>.jpg         all positions of the preset on one sheet (two columns, labelled)
#   <out_dir>/index.txt                  position, preset, arguments, seconds per run, result
# Exit code 1 when one position failed (the others still run).
#
# Environment:
#   PRESETS     presets of the Modern runs, space separated (default "high auto"; auto = no --gfx-preset)
#   SHOT_TIMES  shot times in seconds after the start (default 3: "LOS!" has faded)
#   GFX_EXTRA   further arguments of every Modern run only (e.g. --gfx-debug=cover)
#   SCREEN, GODOT, AB_TIMEOUT   as in tools/ab_shot.sh
#   MESA_SHADER_CACHE_DIR       shared by all runs of the call (default: a folder of the call)
# Runs one picture at a time (heavy job: Xvfb, software OpenGL), with nice -n 10 (inside tools/ab_shot.sh).
set -uo pipefail
if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
	exit 2
fi
OUT=$1
shift
case "$OUT" in
/*) ;;
*) OUT="$PWD/$OUT" ;;
esac
cd "$(dirname "$0")/.."
ROOT=$PWD
POSITIONS=()
EXTRA=()
while [ $# -gt 0 ]; do
	if [ "$1" = "--" ]; then
		shift
		EXTRA=("$@")
		break
	fi
	POSITIONS+=("$1")
	shift
done
ALL=(S1 S2 S3 S4 S5 T1 T2 T3 T4 N1 N2 C1 U1 DEV)
[ ${#POSITIONS[@]} -eq 0 ] && POSITIONS=("${ALL[@]}")
PRESETS=${PRESETS:-high auto}
SHOT_TIMES=${SHOT_TIMES:-3}
mkdir -p "$OUT"
OWN_CACHE=""
if [ -z "${MESA_SHADER_CACHE_DIR:-}" ]; then
	OWN_CACHE=$(mktemp -d "${TMPDIR:-/tmp}/ce_ab_sheet.XXXXXX")
	OWN_CACHE=$(cd "$OWN_CACHE" && pwd)
	export MESA_SHADER_CACHE_DIR="$OWN_CACHE"
fi
trap '[ -n "$OWN_CACHE" ] && rm -rf "$OWN_CACHE"' EXIT

FLY="--autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
SLICE="--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=120"
# position_args <id>: arguments of the race scene for a position ("" = unknown)
position_args() {
	case "$1" in
	S1) echo "$SLICE --start-km=2" ;;
	S2) echo "$SLICE --start-km=13.6" ;;
	S3) echo "$SLICE --start-km=60" ;;
	S4) echo "$SLICE --start-km=80 --start-speed=50" ;;
	S5) echo "$SLICE --start-km=94" ;;
	T1) echo "--stage=kassel_wuerzburg --from=kassel --start-km=46.5 --hour=15 --weather=normal --vehicle=kombi --seed=12 $FLY --start-speed=120" ;;
	T2) echo "--stage=kassel_wuerzburg --from=kassel --start-km=61.9 --hour=15 --weather=normal --vehicle=kombi --seed=12 $FLY --start-speed=120" ;;
	T3) echo "--stage=saragossa_pau --from=saragossa --start-km=172.8 --hour=11 --weather=normal --vehicle=kompakt --seed=4 $FLY --start-speed=80" ;;
	T4) echo "--stage=saragossa_pau --from=saragossa --start-km=198.8 --hour=11 --weather=normal --vehicle=kompakt --seed=4 $FLY --start-speed=80" ;;
	N1) echo "--stage=hamburg_hannover --from=hamburg --start-km=71 --hour=22 --weather=snow --vehicle=kompakt --seed=13 $FLY --start-speed=100" ;;
	N2) echo "--stage=dortmund_frankfurt --from=dortmund --start-km=121 --hour=16 --weather=rain --vehicle=gran_turismo --seed=14 $FLY --start-speed=110" ;;
	C1) echo "--stage=dortmund_frankfurt --from=dortmund --start-km=221 --hour=19.5 --weather=normal --vehicle=sportwagen --seed=15 $FLY --start-speed=90" ;;
	U1) echo "--stage=bern_mailand --from=bern --start-km=186 --hour=12 --weather=normal --vehicle=limousine --seed=16 $FLY --start-speed=100" ;;
	DEV) echo "--stage=dev_testetappe --start-km=48 --hour=21 --weather=normal --vehicle=limousine --seed=17 $FLY --start-speed=100" ;;
	*) echo "" ;;
	esac
}

FONT=()
FONTS=$(convert -list font 2>/dev/null || true)
case "$FONTS" in
*"Font: DejaVu-Sans-Bold"*) FONT=(-font DejaVu-Sans-Bold) ;;
esac
INDEX="$OUT/index.txt"
{
	echo "# tools/ab_sheet.sh – $(date -u '+%Y-%m-%d %H:%M UTC'), commit $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$( [ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ] && echo " (geändert)")"
	echo "# Bildschirm ${SCREEN:-1280x720}, Aufnahmezeit(en) $SHOT_TIMES s, Voreinstellungen: $PRESETS"
} > "$INDEX"
FAILED=0
for q in $PRESETS; do
	for p in "${POSITIONS[@]}"; do
		args=$(position_args "$p")
		if [ -z "$args" ]; then
			echo "==> unbekannte Position $p" >&2
			FAILED=1
			continue
		fi
		gfx=""
		[ "$q" != auto ] && gfx="--gfx-preset=$q"
		t0=$SECONDS
		# shellcheck disable=SC2086
		GFX_ARGS="$gfx${GFX_EXTRA:+ $GFX_EXTRA}" tools/ab_shot.sh "$OUT/${p}_${q}" $args --shot-times="$SHOT_TIMES" \
			${EXTRA[@]+"${EXTRA[@]}"} >"$OUT/${p}_${q}.tool.log" 2>&1
		code=$?
		printf '%-4s %-6s %4d s  %s  %s\n' "$p" "$q" $((SECONDS - t0)) "$([ $code -eq 0 ] && echo OK || echo FEHLER)" "$args $gfx" >> "$INDEX"
		printf '%-4s %-6s %4d s  %s\n' "$p" "$q" $((SECONDS - t0)) "$([ $code -eq 0 ] && echo OK || echo "FEHLER (siehe ${p}_${q}.tool.log)")"
		[ $code -eq 0 ] || FAILED=1
	done
	# overview of this preset: the A/B pictures in two columns, labelled with the position
	tiles=()
	for p in "${POSITIONS[@]}"; do
		for f in "$OUT/${p}_${q}"_ab_[0-9][0-9].jpg; do
			[ -s "$f" ] || continue
			nn=${f##*_ab_}
			nn=${nn%.jpg}
			t="$OUT/.tile_${p}_${q}_${nn}.jpg"
			convert "$f" -resize 1280x -background '#10182c' -fill white ${FONT[@]+"${FONT[@]}"} -pointsize 30 \
				-gravity NorthWest -splice 0x40 -annotate +12+4 "$p" "$t" && tiles+=("$t")
		done
	done
	if [ ${#tiles[@]} -gt 0 ]; then
		label="Arcade | Modern, Voreinstellung $q"
		[ "$q" = auto ] && label="Arcade | Modern, Voreinstellung dieses Rechners"
		montage "${tiles[@]}" -tile 2x -geometry +6+6 -background '#10182c' miff:- \
			| convert - -background '#10182c' -fill white ${FONT[@]+"${FONT[@]}"} -pointsize 40 -gravity North \
				-splice 0x64 -annotate +0+10 "$label" -quality 85 "$OUT/uebersicht_${q}.jpg" \
			&& echo "$OUT/uebersicht_${q}.jpg"
		rm -f "${tiles[@]}"
	fi
done
[ $FAILED -eq 0 ]
