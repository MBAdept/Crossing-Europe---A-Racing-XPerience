#!/bin/bash
# waits for after2.sh (render checks, warm-ups, render mutations), then the B2 fix prototype and the Arcade gate
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-3
until grep -q 'AFTER2 DONE' $S/logs/queue3.log 2>/dev/null; do sleep 15; done
if [ ! -e $S/done/x_b2fix ]; then
	echo "=== $(date +%H:%M:%S) start x_b2fix"
	$S/sh/x_b2fix.sh > $S/logs/x_b2fix.log 2>&1
	echo "rc=$?" > $S/done/x_b2fix
fi
if [ ! -e $S/done/golden ]; then
	echo "=== $(date +%H:%M:%S) start golden check"
	mkdir -p $S/xdg_golden
	(cd $WT && XDG_DATA_HOME=$S/xdg_golden nice -n 10 tools/golden.sh check) > $S/logs/golden_check.log 2>&1
	echo "rc=$?" > $S/done/golden
fi
echo "=== $(date +%H:%M:%S) AFTER4 DONE"
