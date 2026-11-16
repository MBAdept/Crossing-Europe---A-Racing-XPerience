#!/usr/bin/env bash
# A/B pictures of package R2 at the reference positions: ab_all.sh <worktree> <out dir> [ids…]
# The car starts 0.72 stage-km before the reference kilometre: the picture is taken 2 s after the flying start
# at 120 km/h, i.e. at the kilometre itself (50 km/h in the city: 0.3 km).
set -uo pipefail
WT=$1
OUT=$2
shift 2
IDS=("$@")
[ ${#IDS[@]} -eq 0 ] && IDS=(S1 S2 S3 T1 T2 T3 T4 C1)
R2=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R2
export MESA_SHADER_CACHE_DIR=$R2/mesa
export GFX_ARGS="${GFX_ARGS:---gfx-preset=medium}"
mkdir -p "$OUT"
cd "$WT" || exit 1
COMMON="--autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120"
for id in "${IDS[@]}"; do
	case "$id" in
	S1) ARGS="--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --start-km=1.28 $COMMON" ;;
	S2) ARGS="--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --start-km=12.88 $COMMON" ;;
	S3) ARGS="--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --start-km=59.28 $COMMON" ;;
	S4) ARGS="--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --start-km=79.7 $COMMON --start-speed=50" ;;
	T1) ARGS="--stage=kassel_wuerzburg --from=kassel --hour=15 --weather=normal --vehicle=kombi --seed=12 --start-km=45.78 $COMMON" ;;
	T2) ARGS="--stage=kassel_wuerzburg --from=kassel --hour=15 --weather=normal --vehicle=kombi --seed=12 --start-km=61.18 $COMMON" ;;
	T3) ARGS="--stage=saragossa_pau --from=saragossa --hour=11 --weather=normal --vehicle=kompakt --seed=4 --start-km=172.08 $COMMON" ;;
	T4) ARGS="--stage=saragossa_pau --from=saragossa --hour=11 --weather=normal --vehicle=kompakt --seed=4 --start-km=198.08 $COMMON" ;;
	N1) ARGS="--stage=hamburg_hannover --from=hamburg --hour=22 --weather=snow --vehicle=limousine --seed=13 --start-km=70.28 $COMMON" ;;
	R1) ARGS="--stage=kiel_hamburg --from=kiel --hour=19.5 --weather=rain --vehicle=limousine --seed=11 --start-km=59.28 $COMMON" ;;
	C1) ARGS="--stage=dortmund_frankfurt --from=dortmund --hour=19.5 --weather=normal --vehicle=sportwagen --seed=15 --start-km=220.7 $COMMON --start-speed=50" ;;
	*) echo "unknown id $id"; continue ;;
	esac
	# shellcheck disable=SC2086
	tools/ab_shot.sh "$OUT/$id" $ARGS ${EXTRA:-} 2>&1 | tail -3
done
