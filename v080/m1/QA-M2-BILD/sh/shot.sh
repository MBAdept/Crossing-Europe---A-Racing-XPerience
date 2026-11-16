#!/bin/bash
# QA-M2-BILD: one race-scene run in one tree and mode, pictures <out>_NN.png (Screenshotter), log <out>.log
#   shot.sh <tree: m2|zs1> <mode: arcade|modern> <out prefix> <race args...>
# env: SCREEN (1280x720), GFX (extra modern args, e.g. --gfx-preset=high), TIMEOUT (900)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
case "$1" in
m2) WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-3 ;;
zs1) WT=$S/zs1tree ;;
*) echo "tree?"; exit 2 ;;
esac
MODE=$2
OUT=$3
shift 3
SCREEN=${SCREEN:-1280x720}
cd "$WT" || exit 1
X=$S/xdg/shot_$$
rm -rf "$X"; mkdir -p "$X"
export MESA_SHADER_CACHE_DIR=${MESA_SHADER_CACHE_DIR:-$S/mesa}
mkdir -p "$MESA_SHADER_CACHE_DIR"
export LP_NUM_THREADS=${LP_NUM_THREADS:-2}
EXTRA=()
if [ "$MODE" = arcade ]; then EXTRA=(--shot-fast); else EXTRA=(${GFX:-}); fi
t0=$SECONDS
XDG_DATA_HOME=$X nice -n 10 timeout ${TIMEOUT:-900} xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . \
	--rendering-driver opengl3 --audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 res://scenes/race/race.tscn -- \
	"--screenshot=$OUT" "$@" "${EXTRA[@]}" "--graphics=$MODE" --gfx-sync --sound=arcade --no-chooser > "$OUT.log" 2>&1
code=$?
n=$(ls "$OUT"_[0-9][0-9].png 2>/dev/null | wc -l)
bad=$(grep -cE "SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed|Too many instances|Modus Modern nicht möglich" "$OUT.log")
echo "$(date -u +%H:%M:%S) shot $1 $MODE $(basename "$OUT") exit=$code pics=$n bad=$bad $((SECONDS - t0)) s" | tee -a $S/logs/shots.txt
rm -rf "$X"
