#!/bin/bash
# QA-BILD: A/B pictures at the reference positions. Usage: ab.sh <outdir> <preset|machine> <pos> [pos ...] [-- extra args]
# Extra args go to both runs (later args win). Each position writes <outdir>/<pos>[_TAG]_{arcade,modern}_NN.png + _ab_NN.jpg
# Uses abf.sh (Modern with --shot-fast and a lead of LEAD s).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-BILD
OUTDIR=$1; shift
PRESET=$1; shift
POS=()
EXTRA=()
while [ $# -gt 0 ]; do
	if [ "$1" = "--" ]; then shift; EXTRA=("$@"); break; fi
	POS+=("$1"); shift
done
mkdir -p "$OUTDIR"
FLY="--autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
SLICE="--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=120"
if [ "$PRESET" = "machine" ]; then G=""; else G="--gfx-preset=$PRESET"; fi
G="$G ${XGFX:-}"
for p in "${POS[@]}"; do
	case "$p" in
	S1) A=($SLICE --start-km=2) ;;
	S2) A=($SLICE --start-km=13.6) ;;
	S3) A=($SLICE --start-km=60) ;;
	S4) A=($SLICE --start-km=80 --start-speed=50) ;;
	S5) A=($SLICE --start-km=94) ;;
	S1H6) A=($SLICE --start-km=2 --hour=6) ;;
	S1H9) A=($SLICE --start-km=2 --hour=9) ;;
	S1H17) A=($SLICE --start-km=2 --hour=17) ;;
	S1H195) A=($SLICE --start-km=2 --hour=19.5) ;;
	S1H22) A=($SLICE --start-km=2 --hour=22) ;;
	S1H3) A=($SLICE --start-km=2 --hour=3) ;;
	S3H22) A=($SLICE --start-km=60 --hour=22) ;;
	S4H22) A=($SLICE --start-km=80 --start-speed=50 --hour=22) ;;
	S2H22) A=($SLICE --start-km=13.6 --hour=22) ;;
	S1K) A=($SLICE --start-km=2 --vehicle=kombi) ;;
	S1C) A=($SLICE --start-km=2 --vehicle=kompakt) ;;
	S1S) A=($SLICE --start-km=2 --vehicle=sportwagen) ;;
	S1G) A=($SLICE --start-km=2 --vehicle=gran_turismo) ;;
	S1R) A=($SLICE --start-km=2 --weather=rain) ;;
	S1W) A=($SLICE --start-km=2 --weather=snow) ;;
	T1) A=(--stage=kassel_wuerzburg --from=kassel --start-km=46.5 --hour=15 --weather=normal --vehicle=kombi --seed=12 $FLY --start-speed=120) ;;
	T2) A=(--stage=kassel_wuerzburg --from=kassel --start-km=61.9 --hour=15 --weather=normal --vehicle=kombi --seed=12 $FLY --start-speed=120) ;;
	T3) A=(--stage=saragossa_pau --from=saragossa --start-km=172.8 --hour=11 --weather=normal --vehicle=kompakt --seed=4 $FLY --start-speed=80) ;;
	T4) A=(--stage=saragossa_pau --from=saragossa --start-km=198.8 --hour=11 --weather=normal --vehicle=kompakt --seed=4 $FLY --start-speed=80) ;;
	C1) A=(--stage=dortmund_frankfurt --from=dortmund --start-km=221 --hour=19.5 --weather=normal --vehicle=sportwagen --seed=15 $FLY --start-speed=90) ;;
	N1) A=(--stage=hamburg_hannover --from=hamburg --start-km=71 --hour=22 --weather=snow --vehicle=kompakt --seed=13 $FLY --start-speed=100) ;;
	N2) A=(--stage=dortmund_frankfurt --from=dortmund --start-km=121 --hour=16 --weather=rain --vehicle=gran_turismo --seed=14 $FLY --start-speed=110) ;;
	U1) A=(--stage=bern_mailand --from=bern --start-km=186 --hour=12 --weather=normal --vehicle=limousine --seed=16 $FLY --start-speed=100) ;;
	DEV) A=(--stage=dev_testetappe --start-km=48 --hour=21 --weather=normal --vehicle=limousine --seed=17 $FLY --start-speed=100) ;;
	*) echo "unknown position $p"; continue ;;
	esac
	t0=$SECONDS
	tag=${TAG:+_$TAG}
	GFX_ARGS="$G" "$S/tools/abf.sh" "$OUTDIR/$p$tag" "${A[@]}" "${EXTRA[@]}" > "$OUTDIR/$p$tag.tool.log" 2>&1
	echo "$p$tag $((SECONDS - t0)) s $(tr '\n' ' ' < "$OUTDIR/$p$tag.tool.log")"
done
