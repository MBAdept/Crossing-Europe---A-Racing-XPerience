#!/bin/bash
# B-04 mutation check: M03 canopy 5.4 m, M06 border roof 5.8 m, M08 street lamp energy 0.55 – each must turn
# test_structures red. Restores every file with git checkout afterwards.
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-3
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R6
cd "$W" || exit 1
run() {
	local name=$1 file=$2 from=$3 to=$4
	sed -i "s/$from/$to/" "$file"
	grep -c "$to" "$file" > /dev/null || { echo "$name: mutation not applied"; git checkout -- "$file"; return; }
	XDG_DATA_HOME=$S/xdg timeout 900 nice -n 10 godot --headless --path . -s res://tests/run_tests.gd -- --filter=test_structures > "$S/logs/mut_$name.log" 2>&1
	echo "$name: $(grep -E 'Tests, ' "$S/logs/mut_$name.log")"
	git checkout -- "$file"
}
run M03 scripts/race3d/builders/station.gd 'const CANOPY_H := 5.6 ' 'const CANOPY_H := 5.4 '
run M06 scripts/race3d/builders/border.gd 'const ROOF_H := 6.0 ' 'const ROOF_H := 5.8 '
run M08 scripts/race3d/builders/city.gd 'const LAMP_ENERGY := 1.0' 'const LAMP_ENERGY := 0.55'
git status --short
