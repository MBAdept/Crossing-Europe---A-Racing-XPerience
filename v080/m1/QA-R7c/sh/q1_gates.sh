#!/bin/bash
# QA-R7c queue 1: the gates on the R7c head (full tests once, render checks all, sight and path --full)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/sh/common.sh
cd "$WT" || exit 1
step() {
	local name=$1
	shift
	memwait
	local t0=$SECONDS
	export XDG_DATA_HOME=$S/xdg_$name
	mkdir -p "$XDG_DATA_HOME"
	nice -n 10 "$@" > "$S/gates/$name.log" 2>&1
	echo "$(date -u +%H:%M:%S) $name exit=$? $((SECONDS - t0)) s" | tee -a "$S/gates/q1.out"
}
step checkscripts godot --headless --path . -s res://tests/check_scripts.gd
step sight_full godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full
step path_full godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full
step run_tests tools/run_tests.sh
step render_all tools/run_render_checks.sh all
echo "Q1 DONE $(date -u +%H:%M:%S)" | tee -a "$S/gates/q1.out"
