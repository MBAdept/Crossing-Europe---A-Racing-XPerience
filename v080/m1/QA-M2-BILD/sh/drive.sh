#!/bin/bash
# QA-M2-BILD: one probe drive under Xvfb (probe/qa_drive.gd of M1 QA-BILD, unchanged).
#   drive.sh <tree: m2|zs1> <name> <mode> <preset|-> [probe args...]
# writes perf/<name>.log, perf/<name>_frames.csv, perf/<name>_samples.jsonl. Idempotent: skips a finished drive.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
case "$1" in
m2) WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-3 ;;
zs1) WT=$S/zs1tree ;;
*) echo "tree?"; exit 2 ;;
esac
NAME=$2
MODE=$3
PRESET=$4
shift 4
mkdir -p "$S/perf"
if grep -q "^QA-SUMMARY" "$S/perf/$NAME.log" 2> /dev/null; then echo "skip drive $NAME"; exit 0; fi
export XDG_DATA_HOME=$S/xdg/perf_$NAME
rm -rf "$XDG_DATA_HOME"
mkdir -p "$XDG_DATA_HOME"
export MESA_SHADER_CACHE_DIR=${MESA_SHADER_CACHE_DIR:-$S/mesa}
export LP_NUM_THREADS=${LP_NUM_THREADS:-2}
G=()
[ "$PRESET" != "-" ] && G=(--gfx-preset=$PRESET)
cd "$WT" || exit 1
t0=$SECONDS
nice -n 10 timeout ${DRIVE_TIMEOUT:-5400} xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy --resolution 1280x720 -s "${PROBE:-$S/probe/qa_drive.gd}" -- --graphics=$MODE "${G[@]}" --no-watchdog \
	--no-chooser --sound=arcade --out="$S/perf/$NAME" "$@" > "$S/perf/$NAME.log" 2>&1
echo "$(date -u +%H:%M:%S) drive $1 $NAME exit=$? $((SECONDS - t0)) s"
grep -E "^QA-SUMMARY|^QA-LIVE|Too many instances|SCRIPT ERROR|FEHLER" "$S/perf/$NAME.log" | cut -c1-600 | head -5
rm -rf "$XDG_DATA_HOME"
