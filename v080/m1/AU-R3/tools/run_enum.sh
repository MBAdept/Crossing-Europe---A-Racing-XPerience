#!/usr/bin/env bash
# AU-R3: enumeration of the bridges in old-town centres, old feed (3600eb7 copy) vs the tree's feed; nice 19, one process.
set -u
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R3
TREE=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_15398915-ab3-1
mkdir -p "$S/xdg/enum" "$S/res"
cd "$TREE" || exit 2
XDG_DATA_HOME="$S/xdg/enum" nice -n 19 timeout 1500 godot --headless --path . -s "$S/tools/enum_bridges.gd" -- \
	--graphics=arcade --old="$S/tools/audio_feed_3600eb7.gd" > "$S/res/enum.log" 2>&1
rc=$?
echo "exit $rc  bridges $(grep -c '^BRIDGE' "$S/res/enum.log")  centres $(grep -c '^CENTRE' "$S/res/enum.log")"
grep -E '^(DONE|FEHLER|SCRIPT ERROR|ERROR)' "$S/res/enum.log" | head -20
