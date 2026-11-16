#!/bin/bash
# rc.sh <check file basename without .gd> [extra args…] – one render check of my worktree, pictures saved
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R4
WT=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-5}
F=$1; shift
mkdir -p $S/rc/$F $S/xdg/rc
export XDG_DATA_HOME=$S/xdg/rc
export MESA_SHADER_CACHE_DIR=$S/mesa
cd "$WT" || exit 2
t0=$SECONDS
nice -n ${NICE:-10} timeout ${TO:-1500} xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
  --audio-driver Dummy --fixed-fps 60 -s res://tests/race3d/render/$F.gd -- --graphics=modern --gfx-sync --audio-sync \
  --save=$S/rc/$F "$@" > $S/rc/$F.log 2>&1
echo "rc $F exit=$? $((SECONDS-t0))s"
grep -E "RENDER-CHECK|SCRIPT ERROR|SHADER ERROR|Parse Error|compilation failed" $S/rc/$F.log | head -20
