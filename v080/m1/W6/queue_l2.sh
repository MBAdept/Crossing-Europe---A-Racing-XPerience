#!/bin/bash
# W6 AS6 L2+L3: landmark exports after L1 (export + bake, commit, views)
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix
L=$W6/logs/queue_l2.log
until grep -q "QUEUE R3 DONE" $W6/logs/queue_r3.log 2>/dev/null; do sleep 30; done
while read -r -u 3 lm x; do
	[ -f $W6/shots/l2_$lm/dist_h22.png ] && continue
	bash $W6/real.sh landmarks/$lm >> $L 2>&1
	cd $WT
	if [ -n "$(git status --porcelain assets/models)" ]; then
		git add assets/models/manifest.json assets/models/landmarks assets/models/props
		printf 'Welle 6 AS6: Wahrzeichen %s als Modell (WIP, Ansicht folgt)\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01PFUioZ3CbJFXvrcqAMyLYq\n' "$lm" > $W6/msg_auto5.txt
		git commit -q -F $W6/msg_auto5.txt && for i in 1 2 3 4; do git push -q origin wip-v080-welle6:wip/v080-welle6 > /dev/null 2>&1 && break; sleep $((i*5)); done
		echo "$(date +%T) COMMIT $(git log --oneline -1)" >> $L
	fi
	bash $W6/views_lm.sh l2_$lm landmarks/$lm $x >> $L 2>&1
done 3<<LIST
stephansdom 28
riesenrad 60
mariendom_linz 30
dom_passau 20
dom_regensburg 40
veitsdom_prag 60
eiffel_tower 60
atomium 30
basilika_koekelberg 40
beffroi_calais 30
duomo_milano 35
campanile_venezia 160
sagrada_familia 12
basilica_pilar 60
kathedrale_burgos 35
parlament_budapest 180
kulturpalast_warschau 90
freiheitsdenkmal_riga 25
nevsky_kathedrale 30
stadtpfarrkirche_sibiu 30
catedrala_timisoara 20
catedrala_mantuirii 30
palatul_parlamentului 40
LIST
echo "QUEUE L2 DONE $(date +%T)" >> $L
