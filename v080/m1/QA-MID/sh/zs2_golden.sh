#!/bin/bash
# ZS2 step 1 (resumable): render the Modern golden frames with the fix head and write the new list (A-29: the
# integration regenerates it once, after looking at the frames). Frames kept in zs2/golden_modern for viewing.
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/sh/env.sh
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix
head=$(git rev-parse --short HEAD)
if ! grep -q "GOLDEN modern-make $head exit=0" $S/logs/zs2.log 2>/dev/null; then
	rm -rf $S/zs2/golden_modern; mkdir -p $S/zs2/golden_modern
	t0=$SECONDS; KEEP=$S/zs2/golden_modern nice -n 10 tools/golden.sh modern-make > $S/zs2/golden_modern.log 2>&1; rc=$?
	echo "$(date +%T) GOLDEN modern-make $head exit=$rc $((SECONDS - t0)) s" >> $S/logs/zs2.log
fi
echo "ZS2 GOLDEN DONE $(date +%T)" >> $S/logs/zs2.log
