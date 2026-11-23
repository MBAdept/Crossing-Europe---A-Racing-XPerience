#!/usr/bin/env bash
# probe.sh <script.gd> [args after --]: runs a -s script under Xvfb in the worktree (Modern, gfx-sync, high)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7b
W=${TREE:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-6}
SCRIPT=$1; shift
SCREEN=${SCREEN:-1280x720}
while [ "$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)" -lt 3000 ]; do sleep 20; done
X=$S/xdg_probe_$$; rm -rf $X; mkdir -p $X $S/mesa
if [ -n "${OVERRIDE:-}" ]; then mkdir -p "$X/godot/app_userdata/Crossing Europe – A Racing Xperience"; cp "$OVERRIDE" "$X/godot/app_userdata/Crossing Europe – A Racing Xperience/game_config.json"; fi
cd $W && XDG_DATA_HOME=$X MESA_SHADER_CACHE_DIR=$S/mesa nice -n 10 timeout ${PROBE_TIMEOUT:-600} xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . \
	--rendering-driver opengl3 --audio-driver Dummy --resolution $SCREEN --fixed-fps 60 -s "$SCRIPT" -- --graphics=modern --gfx-sync "$@"
rc=$?
rm -rf $X
exit $rc
