#!/bin/bash
# QA-BILD: one probe drive under Xvfb. usage: drive.sh <name> <mode> <preset|-> [probe args...]
# writes perf/<name>.log, perf/<name>_frames.csv, perf/<name>_samples.jsonl
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-2
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-BILD
NAME=$1; shift
MODE=$1; shift
PRESET=$1; shift
mkdir -p "$S/perf"
export XDG_DATA_HOME=$S/xdg_perf_$NAME
rm -rf "$XDG_DATA_HOME"
mkdir -p "$XDG_DATA_HOME"
export MESA_SHADER_CACHE_DIR=${MESA_SHADER_CACHE_DIR:-$S/mesa_ab}
export LP_NUM_THREADS=${LP_NUM_THREADS:-2}
G=()
[ "$PRESET" != "-" ] && G=(--gfx-preset=$PRESET)
cd "$WT" || exit 1
t0=$SECONDS
nice -n 10 timeout ${DRIVE_TIMEOUT:-3600} xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy --resolution 1280x720 -s "$S/probe/qa_drive.gd" -- --graphics=$MODE "${G[@]}" --no-watchdog \
	--no-chooser --sound=arcade --out="$S/perf/$NAME" "$@" > "$S/perf/$NAME.log" 2>&1
echo "$NAME exit=$? $((SECONDS - t0)) s"
grep -E "^QA-SUMMARY|^QA-LIVE|Too many instances|SCRIPT ERROR|FEHLER" "$S/perf/$NAME.log" | cut -c1-1500
