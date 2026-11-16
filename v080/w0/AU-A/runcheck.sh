#!/usr/bin/env bash
# Runs check_modern_audio.gd in the AU-A worktree with a timeout. Usage: runcheck.sh <log name> [extra user args…]
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/AU-A
NAME="${1:-check}"
shift || true
export XDG_DATA_HOME="$W/xdg_check"
mkdir -p "$XDG_DATA_HOME" "$W/logs"
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-3 || exit 1
START=$(date +%s.%N)
timeout -s KILL "${CHECK_TIMEOUT:-120}" nice -n 10 godot --headless --path . -s res://tests/unit/audio_modern/check_modern_audio.gd -- --graphics=arcade "$@" >"$W/logs/$NAME.log" 2>&1
CODE=$?
END=$(date +%s.%N)
grep -E "^CHECK|ERROR|WARNING|leak|still in use" "$W/logs/$NAME.log" | cut -c1-${CUT:-400}
echo "EXIT $CODE  $(echo "$END - $START" | bc) s"
exit $CODE
