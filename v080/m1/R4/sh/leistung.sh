#!/bin/bash
# leistung.sh <tag> [tree] – check_vehicles leistung headless (nice 19), result line appended to leistung.log
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
TREE=${2:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1}
mkdir -p "$R4/xdg_leistung"
cd "$TREE" || exit 2
XDG_DATA_HOME=$R4/xdg_leistung nice -n ${NICE:-19} timeout 900 godot --headless --path . -s res://tests/race3d/check_vehicles.gd \
	-- --only=leistung > "$R4/leistung_$1.out" 2>&1
echo "$1 $(date -u +%T) $(grep -a 'CHECK leistung' "$R4/leistung_$1.out" | cut -c1-260)" >> "$R4/leistung.log"
