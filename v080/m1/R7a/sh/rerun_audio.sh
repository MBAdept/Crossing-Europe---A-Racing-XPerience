#!/bin/bash
# R7a (A-11): the three audio checks that failed under load in the full run – alone, on this tree and on the base.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
for tree in mine base; do
	if [ $tree = base ]; then WT=$S/base; else WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1; fi
	for f in test_engine3_checks test_modern_checks test_music_checks; do
		x=$S/xdg/ra_$$
		rm -rf "$x"; mkdir -p "$x"
		cd "$WT" || exit 1
		r=$(XDG_DATA_HOME=$x nice -n 10 timeout 900 godot --headless --path . -s res://tests/run_tests.gd -- "--filter=$f" 2>&1 | grep -E '^(ok|FAIL)|Tests,' | tr '\n' ' ')
		echo "$(date -u +%H:%M:%S) $tree $f: $r  (load $(cut -d' ' -f1 /proc/loadavg))"
		rm -rf "$x"
	done
done
