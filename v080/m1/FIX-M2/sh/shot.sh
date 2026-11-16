#!/bin/bash
# FIX-M2: one race-scene run on this worktree, pictures <out>_NN.png (Screenshotter), log <out>.log
#   shot.sh <mode: arcade|modern> <out prefix> <race args...>   env: GFX (modern args), TIMEOUT
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-M2
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-5
MODE=$1
OUT=$2
shift 2
cd "$WT" || exit 1
X=$S/xdg/shot_$$
rm -rf "$X"; mkdir -p "$X"
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
EXTRA=()
if [ "$MODE" = arcade ]; then EXTRA=(--shot-fast); else EXTRA=(${GFX:-}); fi
t0=$SECONDS
XDG_DATA_HOME=$X nice -n 10 timeout ${TIMEOUT:-900} xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
	--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 res://scenes/race/race.tscn -- \
	"--screenshot=$OUT" "$@" "${EXTRA[@]}" "--graphics=$MODE" --gfx-sync --sound=arcade --no-chooser > "$OUT.log" 2>&1
code=$?
n=$(ls "$OUT"_[0-9][0-9].png 2>/dev/null | wc -l)
bad=$(grep -cE "SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed|Too many instances|Modus Modern nicht möglich" "$OUT.log")
echo "$(date -u +%H:%M:%S) shot $MODE $(basename "$OUT") exit=$code pics=$n bad=$bad $((SECONDS - t0)) s"
rm -rf "$X"
