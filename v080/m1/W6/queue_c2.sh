#!/bin/bash
# W6 C2 (after the C1 queue): round 2 of the Spanish house, then the 13 sets of batch 2. Per id: export + bake (real.sh),
# commit + push (WIP), review views. Resumable: a batch-2 id whose views exist is skipped.
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix
L=$W6/logs/queue_c2.log
until grep -q "QUEUE C1 DONE" $W6/logs/queue_c1.log && grep -q "AUTOVIEWS DONE" $W6/logs/autoviews.log 2>/dev/null; do sleep 20; done
one() { # tag id
	bash $W6/real.sh props/city_$2 >> $L 2>&1
	cd $WT
	if [ -n "$(git status --porcelain assets/models)" ]; then
		git add assets/models/manifest.json assets/models/props
		printf 'Welle 6 AS5b: city_%s als Modell (%s, WIP, Ansicht folgt)\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01PFUioZ3CbJFXvrcqAMyLYq\n' "$2" "$1" > $W6/msg_auto2.txt
		git commit -q -F $W6/msg_auto2.txt && for i in 1 2 3 4; do git push -q origin wip-v080-welle6:wip/v080-welle6 > /dev/null 2>&1 && break; sleep $((i*5)); done
		echo "$(date +%T) COMMIT $(git log --oneline -1)" >> $L
	fi
	bash $W6/views.sh $1_$2 props/city_$2 9 >> $L 2>&1
}
[ -f $W6/shots/r2_spanish_casa/lods_h22.png ] || one r2 spanish_casa
for s in central_jugendstil central_barock central_eckturm eastern_house_a eastern_house_c eastern_house_b balkan_house balkan_house_b balkan_plattenbau balkan_church baltic_jugendstil baltic_wood baltic_wood_b; do
	[ -f $W6/shots/r1_$s/lods_h22.png ] && continue
	one r1 $s
done
echo "QUEUE C2 DONE $(date +%T)" >> $L
