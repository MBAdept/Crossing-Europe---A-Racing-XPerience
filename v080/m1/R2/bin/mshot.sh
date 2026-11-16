#!/usr/bin/env bash
# mshot.sh <out folder> <id> [extra game args…] – Modern only, one picture 2 s after the flying start at a reference
# position (same table as ab_all.sh). Picture: <out>/<id>_modern_00.png. GFX_ARGS default --gfx-preset=medium.
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_145e8e23-1e4-2
R2=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R2
OUT=$1
id=$2
shift 2
export MESA_SHADER_CACHE_DIR=$R2/mesa
GFX=${GFX_ARGS:---gfx-preset=medium}
mkdir -p "$OUT" "$R2/xdg_m"
COMMON="--autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=120"
case "$id" in
S1) ARGS="--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --start-km=1.28 $COMMON" ;;
S2) ARGS="--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --start-km=12.88 $COMMON" ;;
S3) ARGS="--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --start-km=59.28 $COMMON" ;;
S4) ARGS="--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --start-km=79.7 $COMMON --start-speed=50" ;;
T1) ARGS="--stage=kassel_wuerzburg --from=kassel --hour=15 --weather=normal --vehicle=kombi --seed=12 --start-km=45.78 $COMMON" ;;
T2) ARGS="--stage=kassel_wuerzburg --from=kassel --hour=15 --weather=normal --vehicle=kombi --seed=12 --start-km=61.18 $COMMON" ;;
T3) ARGS="--stage=saragossa_pau --from=saragossa --hour=11 --weather=normal --vehicle=kompakt --seed=4 --start-km=172.08 $COMMON" ;;
T4) ARGS="--stage=saragossa_pau --from=saragossa --hour=11 --weather=normal --vehicle=kompakt --seed=4 --start-km=198.08 $COMMON" ;;
C1) ARGS="--stage=dortmund_frankfurt --from=dortmund --hour=19.5 --weather=normal --vehicle=sportwagen --seed=15 --start-km=220.7 $COMMON --start-speed=50" ;;
N1) ARGS="--stage=hamburg_hannover --from=hamburg --hour=22 --weather=snow --vehicle=limousine --seed=13 --start-km=70.28 $COMMON" ;;
*) echo "unknown id $id"; exit 2 ;;
esac
cd "$WT" || exit 1
t0=$SECONDS
# shellcheck disable=SC2086
XDG_DATA_HOME=$R2/xdg_m nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
	--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 res://scenes/race/race.tscn -- \
	"--screenshot=$OUT/${id}_modern" $ARGS --shot-times=2 "$@" --graphics=modern --gfx-sync $GFX >"$OUT/${id}_modern.log" 2>&1
code=$?
grep -E "SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed|^ERROR|nicht möglich" "$OUT/${id}_modern.log" | head -8
echo "$id exit $code $((SECONDS - t0)) s -> $OUT/${id}_modern_00.png"
