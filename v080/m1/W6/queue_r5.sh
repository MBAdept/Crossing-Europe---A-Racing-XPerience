#!/bin/bash
# W6: second batch of landmark re-exports (gold domes as vpbr, 1024² atlases as WebP), then the gates may run
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix
L=$W6/logs/queue_r5.log
true
for s in nevsky_kathedrale catedrala_mantuirii beffroi_calais campanile_venezia freiheitsdenkmal_riga; do
	[ -f $W6/shots/r3_$s/dist_h22.png ] && continue
	bash $W6/real.sh landmarks/$s >> $L 2>&1
	cd $WT
	if [ -n "$(git status --porcelain assets/models)" ]; then
		git add assets/models/manifest.json assets/models/landmarks
		printf 'Welle 6 AS6: Wahrzeichen %s neu (Goldkuppeln vpbr bzw. Atlas als WebP)\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01PFUioZ3CbJFXvrcqAMyLYq\n' "$s" > $W6/msg_auto8.txt
		git commit -q -F $W6/msg_auto8.txt && for i in 1 2 3 4; do git push -q origin wip-v080-welle6:wip/v080-welle6 > /dev/null 2>&1 && break; sleep $((i*5)); done
		echo "$(date +%T) COMMIT $(git log --oneline -1)" >> $L
	fi
	bash $W6/views_lm.sh r3_$s landmarks/$s 60 >> $L 2>&1
	python3 tools/blender/validate_models.py --only=landmarks/$s > $W6/logs/validate_r5.log 2>&1; echo "VALIDATE rc $?" >> $L
done
echo "QUEUE R5 DONE $(date +%T)" >> $L
