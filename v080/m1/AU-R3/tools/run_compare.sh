#!/usr/bin/env bash
# AU-R3: old vs new feed along one stage on the real Track (deterministic); nice 19, one process.
#   run_compare.sh <label> <stage> <from>
set -u
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R3
TREE=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_15398915-ab3-1
mkdir -p "$S/xdg/cmp" "$S/res"
cd "$TREE" || exit 2
XDG_DATA_HOME="$S/xdg/cmp" nice -n 19 timeout 1500 godot --headless --path . -s "$S/tools/stage_compare.gd" -- \
	--graphics=arcade --old="$S/tools/audio_feed_3600eb7.gd" --stage="$2" --from="$3" > "$S/res/cmp_$1.log" 2>&1
rc=$?
echo "$1 exit $rc"
grep -E '^(RESULT|STRETCH|DIFF|FEHLER|SCRIPT ERROR|ERROR)' "$S/res/cmp_$1.log" | head -30
