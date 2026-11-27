#!/bin/bash
# W6: prop_baked drops slivers (min_height 1e-4) - frankfurt_skyline (11 faces inside out) and beffroi_calais anew
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix
L=$W6/logs/queue_r7.log
for s in frankfurt_skyline beffroi_calais; do
	[ -f $W6/shots/r5_$s/dist_h22.png ] && continue
	bash $W6/real.sh landmarks/$s >> $L 2>&1
	cd $WT
	echo "SLIVERS $s $(/home/user/tools/bpyenv/bin/python -I $W6/glb_thin.py tools/blender/_cache3d/landmarks/$s/model.glb 0.0001 | tail -1)" >> $L
	git add tools/blender/ce3d/props3d.py assets/models/manifest.json assets/models/landmarks
	if [ -n "$(git diff --cached --name-only)" ]; then
		printf 'Welle 6 AS6: Wahrzeichen-Bauer verwirft Splitter unter 0,1 mm, %s neu\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01PFUioZ3CbJFXvrcqAMyLYq\n' "$s" > $W6/msg_auto10.txt
		git commit -q -F $W6/msg_auto10.txt && for i in 1 2 3 4; do git push -q origin wip-v080-welle6:wip/v080-welle6 > /dev/null 2>&1 && break; sleep $((i*5)); done
		echo "$(date +%T) COMMIT $(git log --oneline -1)" >> $L
	fi
	bash $W6/views_lm.sh r5_$s landmarks/$s 60 >> $L 2>&1
done
cd $WT
python3 tools/blender/validate_models.py > $W6/logs/validate_r7.log 2>&1; echo "VALIDATE rc $?" >> $L
echo "QUEUE R7 DONE $(date +%T)" >> $L
