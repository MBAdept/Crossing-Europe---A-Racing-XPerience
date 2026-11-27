#!/bin/bash
# W6: after R5, nevsky and mantuirii again without automatic levels (lamp channel on vpbr, contract A-4), then gates
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix
L=$W6/logs/queue_r6.log
until grep -q "QUEUE R5 DONE" $W6/logs/queue_r5.log 2>/dev/null; do sleep 30; done
for s in nevsky_kathedrale catedrala_mantuirii; do
	[ -f $W6/shots/r4_$s/dist_h22.png ] && continue
	bash $W6/real.sh landmarks/$s >> $L 2>&1
	cd $WT
	git add tools/blender/ce3d/catalog3d.py assets/models/manifest.json assets/models/landmarks
	if [ -n "$(git diff --cached --name-only)" ]; then
		printf 'Welle 6 AS6: %s ohne automatische Stufen (Lampenkanal auf vpbr, Vertrag A-4)\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01PFUioZ3CbJFXvrcqAMyLYq\n' "$s" > $W6/msg_auto9.txt
		git commit -q -F $W6/msg_auto9.txt && for i in 1 2 3 4; do git push -q origin wip-v080-welle6:wip/v080-welle6 > /dev/null 2>&1 && break; sleep $((i*5)); done
		echo "$(date +%T) COMMIT $(git log --oneline -1)" >> $L
	fi
	bash $W6/views_lm.sh r4_$s landmarks/$s 60 >> $L 2>&1
done
cd $WT
python3 tools/blender/validate_models.py > $W6/logs/validate_r6.log 2>&1; echo "VALIDATE rc $?" >> $L
echo "QUEUE R6 DONE $(date +%T)" >> $L
