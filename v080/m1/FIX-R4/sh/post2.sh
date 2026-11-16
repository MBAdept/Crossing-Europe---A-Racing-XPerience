#!/bin/bash
# post2.sh – after post.sh: one more base stage run (are the spikes of the head runs load?) and a third head run
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-5
G=$S/gates
until grep -q POST_DONE $G/gates.log 2>/dev/null; do sleep 30; done
for t in base2 head3; do
	echo "== stage_$t start $(date -u +%T)" >> $G/gates.log
	if [ "$t" = base2 ]; then $S/sh/stage.sh $t $S/base > $G/stage_$t.log 2>&1; else $S/sh/stage.sh $t $WT > $G/stage_$t.log 2>&1; fi
	echo "== stage_$t exit=$? $(date -u +%T)" >> $G/gates.log
done
echo POST2_DONE >> $G/gates.log
