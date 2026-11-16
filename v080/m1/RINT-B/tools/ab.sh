#!/bin/bash
# A/B pictures at the reference positions of the brief. Usage: ab.sh <outdir> <preset|machine> <pos> [pos …] [-- extra args]
# pos: S1 S2 S3 S4 S5 T1 T4 C1 N1 N2 S1N S4N (night variants 22:00) S1K S1S S1G (S1 with kombi/sportwagen/gran_turismo)
WT=${TREE:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-1}
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-B
OUTDIR=$1; shift
PRESET=$1; shift
POS=()
EXTRA=()
while [ $# -gt 0 ]; do
	if [ "$1" = "--" ]; then shift; EXTRA=("$@"); break; fi
	POS+=("$1"); shift
done
mkdir -p "$OUTDIR"
export MESA_SHADER_CACHE_DIR=$S/mesa_ab
mkdir -p "$MESA_SHADER_CACHE_DIR"
export TMPDIR=$S/tmp
mkdir -p "$TMPDIR"
FLY="--weather=normal --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
if [ "$PRESET" = "machine" ]; then G=""; else G="--gfx-preset=$PRESET"; fi
cd "$WT" || exit 1
for p in "${POS[@]}"; do
	case "$p" in
	S1|S2|S3|S4|S5) A=("$p") ;;
	S1N) A=(S1 --hour=22) ;;
	S4N) A=(S4 --hour=22) ;;
	S2N) A=(S2 --hour=22) ;;
	S1K) A=(S1 --vehicle=kombi) ;;
	S1C) A=(S1 --vehicle=kompakt) ;;
	S1CD) A=(S1 --vehicle=kompakt --hour=19.5) ;;
	S1D) A=(S1 --hour=19.5) ;;
	S3C) A=(S3 --vehicle=kompakt) ;;
	S1S) A=(S1 --vehicle=sportwagen) ;;
	S1G) A=(S1 --vehicle=gran_turismo) ;;
	T1) A=(--stage=kassel_wuerzburg --from=kassel --start-km=46.5 --hour=15 --vehicle=kombi --seed=12 $FLY --start-speed=120) ;;
	T2) A=(--stage=kassel_wuerzburg --from=kassel --start-km=61.9 --hour=15 --vehicle=kombi --seed=12 $FLY --start-speed=120) ;;
	T4) A=(--stage=saragossa_pau --from=saragossa --start-km=198.8 --hour=11 --vehicle=kompakt --seed=4 $FLY --start-speed=80) ;;
	C1) A=(--stage=dortmund_frankfurt --from=dortmund --start-km=221 --hour=19.5 --vehicle=sportwagen --seed=15 $FLY --start-speed=90) ;;
	N1) A=(--stage=hamburg_hannover --from=hamburg --start-km=71 --hour=22 --vehicle=kompakt --seed=13 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=100 --weather=snow) ;;
	N2) A=(--stage=dortmund_frankfurt --from=dortmund --start-km=121 --hour=16 --vehicle=gran_turismo --seed=14 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=110 --weather=rain) ;;
	U1) A=(--stage=bern_mailand --from=bern --start-km=186 --hour=12 --vehicle=limousine --seed=16 $FLY --start-speed=100) ;;
	*) echo "unknown position $p"; continue ;;
	esac
	t0=$SECONDS
	GFX_ARGS="$G" nice -n 10 tools/ab_shot.sh "$OUTDIR/$p" "${A[@]}" "${EXTRA[@]}" > "$OUTDIR/$p.tool.log" 2>&1
	echo "$p exit=$? $((SECONDS - t0)) s"
done
