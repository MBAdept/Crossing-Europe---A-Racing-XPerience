#!/usr/bin/env bash
# AU-R3: one trigger log (autopilot, headless, Modern sound, timescale 8) of the worktree, nice 19, one process.
#   run_trig.sh <label> <stage> <from> <start_km>
set -u
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R3
TREE=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_15398915-ab3-1
mkdir -p "$S/trig" "$S/xdg/trig"
cd "$TREE" || exit 2
XDG_DATA_HOME="$S/xdg/trig" nice -n 19 timeout 1200 godot --headless --path . -s "$S/tools/trigger_log2.gd" -- \
	--graphics=arcade --sound=modern --stage="$2" --from="$3" --start-km="$4" --timescale=8 --max-seconds=900 \
	> "$S/trig/$1.log" 2>&1
rc=$?
echo "$1 exit $rc rows $(grep -c '^ROW' "$S/trig/$1.log") events $(grep -c '^EV' "$S/trig/$1.log")"
grep -E '^(ERGEBNIS|FEHLER|SCRIPT ERROR)' "$S/trig/$1.log" | cut -c1-200
