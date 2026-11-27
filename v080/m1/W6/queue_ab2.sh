#!/bin/bash
# W6: after the C2 queue: round 2 of the sets in r2_list.txt (export + commit + views), then the A/B pictures of the
# C2 cities (ab_c2.txt) - so the A/B shows the round-2 versions. Resumable.
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix
L=$W6/logs/queue_r2.log
until grep -q "QUEUE C2 DONE" $W6/logs/queue_c2.log; do sleep 30; done
for s in $(cat $W6/r2_list.txt); do
	[ -f $W6/shots/r2_$s/lods_h22.png ] && continue
	bash $W6/real.sh props/city_$s >> $L 2>&1
	cd $WT
	if [ -n "$(git status --porcelain assets/models)" ]; then
		git add assets/models/manifest.json assets/models/props
		printf 'Welle 6 AS5b: city_%s Runde 2 (WIP, Ansicht folgt)\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01PFUioZ3CbJFXvrcqAMyLYq\n' "$s" > $W6/msg_auto4.txt
		git commit -q -F $W6/msg_auto4.txt && for i in 1 2 3 4; do git push -q origin wip-v080-welle6:wip/v080-welle6 > /dev/null 2>&1 && break; sleep $((i*5)); done
		echo "$(date +%T) COMMIT $(git log --oneline -1)" >> $L
	fi
	bash $W6/views.sh r2_$s props/city_$s 9 >> $L 2>&1
done
echo "QUEUE R2 DONE $(date +%T)" >> $L
bash $W6/ab.sh $W6/ab_c2.txt ab_c2
