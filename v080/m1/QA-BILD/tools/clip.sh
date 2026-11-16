#!/bin/bash
# QA-BILD clip: Movie Maker recording of the race scene at a fixed 60 fps (autopilot), one mode.
# usage: clip.sh <out.avi> <mode> <frames> <preset|-> <race args...>
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-2
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-BILD
OUT=$1; shift
MODE=$1; shift
FRAMES=$1; shift
PRESET=$1; shift
export XDG_DATA_HOME=$S/xdg_clip_$MODE
mkdir -p "$XDG_DATA_HOME"
export MESA_SHADER_CACHE_DIR=$S/mesa_ab
export LP_NUM_THREADS=${LP_NUM_THREADS:-2}
G=()
[ "$PRESET" != "-" ] && G=(--gfx-preset=$PRESET)
cd "$WT" || exit 1
t0=$SECONDS
nice -n 10 timeout 3000 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 1280x720 --write-movie "$OUT" --fixed-fps 60 --quit-after "$FRAMES" res://scenes/race/race.tscn -- \
	"$@" --graphics=$MODE --sound=arcade --no-watchdog --no-chooser "${G[@]}" > "${OUT%.avi}.log" 2>&1
echo "$OUT exit=$? $((SECONDS - t0)) s"
