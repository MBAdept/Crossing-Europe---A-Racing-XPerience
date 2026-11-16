#!/usr/bin/env bash
# Runs tests/race/run_stage.gd headless in the AU-A worktree with its own XDG_DATA_HOME.
# Usage: stage.sh <name> <placeholders: 0|1> <user args…>     log: logs/stage_<name>.log
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A
NAME="$1"
PH="$2"
shift 2
export XDG_DATA_HOME="$W/xdg_stage_$NAME"
rm -rf "$XDG_DATA_HOME"
U="$XDG_DATA_HOME/godot/app_userdata/Crossing Europe – A Racing Xperience"
mkdir -p "$U" "$W/logs"
if [ "$PH" = "1" ]; then
	echo '{"audio": {"modern": {"placeholders": true}}}' >"$U/game_config.json"
fi
cd "${TREE:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3}" || exit 1
START=$(date +%s)
timeout -s KILL "${STAGE_TIMEOUT:-1500}" nice -n 10 godot --headless --path . -s res://tests/race/run_stage.gd -- "$@" >"$W/logs/stage_$NAME.log" 2>&1
CODE=$?
END=$(date +%s)
echo "EXIT $CODE  ($((END - START)) s)" >>"$W/logs/stage_$NAME.log"
grep -E "^ERGEBNIS|^RUN|ERROR|SCRIPT|WARNING|ModernAudio|EXIT" "$W/logs/stage_$NAME.log" | cut -c1-600
exit $CODE
