#!/bin/bash
# RINT-M2: one run of the race scene (like tools/ab_shot.sh, one mode) on a tree.
#   mshot.sh <tree: wt|merged|A|B|path> <mode> <name> <POS> <preset> [extra args...]
#   -> shots/<name>_<mode>_NN.png, shots/<name>_<mode>.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
case "$1" in
wt) T=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1 ;;
merged) T=$S/merged ;;
[A-H]) T=$S/snap_$1 ;;
*) T=$1 ;;
esac
MODE=$2; NAME=$3; POS=$4; PRESET=$5; shift 5
ARGS=$("$S/sh/pos.sh" "$POS") || exit 2
OUT=${OUTDIR:-$S/shots}/$NAME
mkdir -p "$(dirname "$OUT")"
x=$S/xdg/shot_$$
rm -rf "$x"; mkdir -p "$x"
rm -f "${OUT}_${MODE}"_[0-9][0-9].png
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
SCREEN=${SCREEN:-1280x720}
EXTRA=""
[ "$MODE" = arcade ] && EXTRA="--shot-fast"
[ "$MODE" = modern ] && EXTRA="--gfx-preset=$PRESET"
cd "$T" || exit 2
t0=$SECONDS
# shellcheck disable=SC2086
XDG_DATA_HOME="$x" nice -n 10 timeout ${TO:-900} xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . \
	--rendering-driver opengl3 --audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 res://scenes/race/race.tscn -- \
	"--screenshot=${OUT}_${MODE}" $ARGS "$@" $EXTRA --graphics=$MODE --gfx-sync > "${OUT}_${MODE}.log" 2>&1
code=$?
echo "$(date -u +%H:%M:%S) shot $1 $MODE $NAME exit=$code $((SECONDS - t0))s pics=$(ls "${OUT}_${MODE}"_*.png 2> /dev/null | wc -l)"
grep -E "SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed|Modus Modern nicht|Too many instances" "${OUT}_${MODE}.log" | head -5
rm -rf "$x"
