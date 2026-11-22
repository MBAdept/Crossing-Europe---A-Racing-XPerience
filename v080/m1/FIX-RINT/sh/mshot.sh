#!/bin/bash
# mshot.sh <out_prefix> [race args...] : Modern only, like ab_shot's modern run (GFX_ARGS honoured), XDG/Mesa in scratch
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-RINT
W=${W:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-4}
OUT=$1; shift
export XDG_DATA_HOME=$S/xdg/mshot
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
mkdir -p $XDG_DATA_HOME "$(dirname $OUT)"
cd $W
t0=$SECONDS
nice -n 10 timeout ${TO:-900} xvfb-run -a -s "-screen 0 ${SCREEN:-1280x720}x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  --resolution ${SCREEN:-1280x720} --fixed-fps 60 res://scenes/race/race.tscn -- "--screenshot=${OUT}_modern" "$@" --graphics=modern --gfx-sync ${GFX_ARGS:-} > ${OUT}_modern.log 2>&1
echo "exit=$? $((SECONDS-t0))s" | tee -a ${OUT}_modern.log
grep -E "SCRIPT ERROR|SHADER ERROR|Modus Modern nicht" ${OUT}_modern.log | head -3
