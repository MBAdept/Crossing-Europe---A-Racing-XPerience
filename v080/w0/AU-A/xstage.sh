#!/usr/bin/env bash
# Runs a script of the AU-A worktree under Xvfb (software OpenGL, Dummy audio driver) with its own XDG_DATA_HOME.
# Usage: xstage.sh <name> <placeholders: 0|1> <res:// script> <user args…>     log: logs/x_<name>.log
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A
NAME="$1"
PH="$2"
SCRIPT="$3"
shift 3
export XDG_DATA_HOME="$W/xdg_x_$NAME"
export MESA_SHADER_CACHE_DIR="$W/mesa_cache"
rm -rf "$XDG_DATA_HOME"
U="$XDG_DATA_HOME/godot/app_userdata/Crossing Europe – A Racing Xperience"
mkdir -p "$U" "$W/logs" "$MESA_SHADER_CACHE_DIR"
if [ "$PH" = "1" ]; then
	echo '{"audio": {"modern": {"placeholders": true}}}' >"$U/game_config.json"
fi
cd "${TREE:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3}" || exit 1
START=$(date +%s)
timeout -s KILL "${STAGE_TIMEOUT:-900}" nice -n 10 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy -s "$SCRIPT" -- "$@" >"$W/logs/x_$NAME.log" 2>&1
CODE=$?
END=$(date +%s)
echo "EXIT $CODE  ($((END - START)) s)" >>"$W/logs/x_$NAME.log"
grep -E "^ERGEBNIS|^RUN|^CHECK|ERROR|SCRIPT|WARNING|ModernAudio|AUDIO_PERF|EXIT" "$W/logs/x_$NAME.log" | cut -c1-${CUT:-500}
exit $CODE
