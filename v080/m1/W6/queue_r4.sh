#!/bin/bash
# W6: eiffel_tower again with drop_caps (lod0 over 25,000) after L2, before the gates
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix
L=$W6/logs/queue_r4.log
until grep -q "QUEUE L2 DONE" $W6/logs/queue_l2.log; do sleep 30; done
for s in eiffel_tower atomium nevsky_kathedrale catedrala_mantuirii beffroi_calais campanile_venezia freiheitsdenkmal_riga; do
	[ -f $W6/shots/r2_$s/dist_h22.png ] && continue
	bash $W6/real.sh landmarks/$s >> $L 2>&1
	cd $WT
	if [ -n "$(git status --porcelain assets/models)" ]; then
		git add assets/models/manifest.json assets/models/landmarks
		printf 'Welle 6 AS6: Wahrzeichen %s ohne Stirnflaechen der Gittertraeger\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01PFUioZ3CbJFXvrcqAMyLYq\n' "$s" > $W6/msg_auto7.txt
		git commit -q -F $W6/msg_auto7.txt && for i in 1 2 3 4; do git push -q origin wip-v080-welle6:wip/v080-welle6 > /dev/null 2>&1 && break; sleep $((i*5)); done
		echo "$(date +%T) COMMIT $(git log --oneline -1)" >> $L
	fi
	bash $W6/views_lm.sh r2_$s landmarks/$s 60 >> $L 2>&1
	python3 tools/blender/validate_models.py --only=landmarks/$s > $W6/logs/validate_r4.log 2>&1; echo "VALIDATE rc $?" >> $L
done
echo "QUEUE R4 DONE $(date +%T)" >> $L
