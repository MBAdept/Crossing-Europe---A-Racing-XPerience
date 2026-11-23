#!/bin/bash
# Export the 4-way merge probe (FIX-R7c + FIX-RINT + FIX-R7a + FIX-R7b, chain order R7A R7B RINT C7) from the scratch
# clone into m1/NACH-R7c/m4 (git archive + .godot of the worktree), show its diff stat against the head, then import.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7c
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-12
M=$(cat "$S/merge4.sha")
cd "$S/mclone" || exit 1
echo "merge commit $M"
git diff --stat 3b3107be4df09c01aff907a026a709ac0195faea "$M" | tail -45
git diff --name-only 3b3107be4df09c01aff907a026a709ac0195faea "$M" | grep -c "^assets/models/"
if [ "${1:-}" = "export" ]; then
	rm -rf "$S/m4"
	mkdir -p "$S/m4"
	git archive "$M" | tar -x -C "$S/m4"
	cp -a "$WT/.godot" "$S/m4/"
	grep -c "^<<<<<<<" "$S/m4/docs/renderer-modern.md"
	cd "$S/m4" || exit 1
	XDG_DATA_HOME=$S/xdg_gate nice -n 10 timeout 1500 godot --headless --path . --import . > "$S/m4.import.log" 2>&1
	echo "import exit $?"
	grep -ciE "error" "$S/m4.import.log"
fi
