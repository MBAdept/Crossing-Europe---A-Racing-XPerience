#!/usr/bin/env bash
# R7b: one scratch probe (render-check style) under Xvfb after the queue: probe_run.sh <probe.gd> <log>
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7b
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-2
until grep -q MASTER3_DONE $S/master3.log; do sleep 20; done
while [ "$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)" -lt 3000 ]; do sleep 20; done
export XDG_DATA_HOME=$S/xdg TMPDIR=$S/tmp MESA_SHADER_CACHE_DIR=$S/mesa
cd $WT
nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 1280x720 -s "$1" -- --graphics=modern --gfx-sync --audio-sync > "$2" 2>&1
echo "probe exit $?" >> "$2"
