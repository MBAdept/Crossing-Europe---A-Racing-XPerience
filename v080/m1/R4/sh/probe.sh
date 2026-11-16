#!/bin/bash
# probe.sh <script res path> [args…] – one probe script under Xvfb (nice 19), log in probe/<name>.log
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
WT=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1}
S=$1
shift
NAME=$(basename "$S" .gd)
export XDG_DATA_HOME=$R4/xdg_probe
export MESA_SHADER_CACHE_DIR=$R4/mesa
mkdir -p "$XDG_DATA_HOME" "$R4/probe/out"
cd "$WT" || exit 2
nice -n ${NICE:-19} timeout ${PROBE_TIMEOUT:-2400} xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
  --audio-driver Dummy --fixed-fps 60 -s "$S" -- --graphics=modern --gfx-sync --audio-sync "$@" > "$R4/probe/$NAME.log" 2>&1
echo "exit=$?" >> "$R4/probe/$NAME.log"
grep -a "PROBE\|SCRIPT ERROR\|SHADER ERROR\|exit=" "$R4/probe/$NAME.log" | cut -c1-900
