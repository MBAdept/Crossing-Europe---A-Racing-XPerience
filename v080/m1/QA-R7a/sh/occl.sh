#!/bin/bash
# QA-R7a: occlusion probe (FIX-M2/QA-M2-BILD probe/qa_occl.gd, unchanged): red test car in three lanes at 25–270 m,
# Modern "high". occl.sh <mine|base|fix> <tag> <race args...>   (fix = m1/QA-R7a/mut with the reach call in props.gd)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7a
PROBE=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-M2/probe/qa_occl.gd
WHICH=$1
TAG=$2
shift 2
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-5
[ "$WHICH" = base ] && WT=$S/base
[ "$WHICH" = fix ] && WT=$S/mut
O=$S/occl
mkdir -p "$O" "$S/mesa"
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
x=$S/xdg/occ_$$
rm -rf "$x"; mkdir -p "$x"
while [ "$(awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo)" -lt 3 ]; do sleep 20; done
t0=$SECONDS
(cd "$WT" && XDG_DATA_HOME=$x nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
	--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s "$PROBE" -- \
	--graphics=modern --gfx-preset=high --gfx-sync --sound=arcade --out="$O" --tag="${TAG}_$WHICH" \
	--dists=25,55,85,120,150,200,270 "$@" > "$O/${TAG}_$WHICH.log" 2>&1)
echo "$(date -u +%H:%M:%S) occl $WHICH $TAG exit=$? $((SECONDS - t0)) s"
rm -rf "$x"
