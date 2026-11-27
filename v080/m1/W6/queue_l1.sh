#!/bin/bash
# W6 AS6 L1: landmark exports in the A/B slot (starts when the A/B pictures are done): export + bake, commit, views
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix
L=$W6/logs/queue_l1.log
# (05:41 26.11.: startet sofort, neben einer A/B-Kette)
while read -r -u 3 lm x; do
	[ -f $W6/shots/l1_$lm/dist_h22.png ] && continue
	bash $W6/real.sh landmarks/$lm >> $L 2>&1
	cd $WT
	if [ -n "$(git status --porcelain assets/models)" ]; then
		git add assets/models/manifest.json assets/models/landmarks assets/models/props
		printf 'Welle 6 AS6: Wahrzeichen %s als Modell (WIP, Ansicht folgt)\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01PFUioZ3CbJFXvrcqAMyLYq\n' "$lm" > $W6/msg_auto3.txt
		git commit -q -F $W6/msg_auto3.txt && for i in 1 2 3 4; do git push -q origin wip-v080-welle6:wip/v080-welle6 > /dev/null 2>&1 && break; sleep $((i*5)); done
		echo "$(date +%T) COMMIT $(git log --oneline -1)" >> $L
	fi
	bash $W6/views_lm.sh l1_$lm landmarks/$lm $x >> $L 2>&1
done 3<<LIST
elbphilharmonie 55
kaiserburg_nuernberg 60
dom_fulda 25
koelner_dom 40
frauenkirche_dresden 40
frauenkirche_muenchen 35
st_petri_riga 30
fernsehturm_berlin 70
frankfurt_skyline 60
LIST
echo "QUEUE L1 DONE $(date +%T)" >> $L
