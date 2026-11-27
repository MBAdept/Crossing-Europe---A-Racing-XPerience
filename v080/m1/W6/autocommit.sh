#!/bin/bash
# W6: commit + push every finished model export of the C1 queue as WIP (safety copy; review follows)
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix
seen=$(grep -c '=== real fertig' $W6/logs/queue_c1.log)
while true; do
	n=$(grep -c '=== real fertig' $W6/logs/queue_c1.log)
	if [ "$n" -gt "$seen" ]; then
		seen=$n
		sleep 5
		new=$(git status --porcelain assets/models/props | sed -n 's#^?? assets/models/props/\(city_[a-z_]*\)/$#\1#p' | tr '\n' ' ')
		if [ -n "$(git status --porcelain assets/models)" ]; then
			git add assets/models/manifest.json assets/models/props
			printf 'Welle 6 AS5b: %s als Modell, erster Export (WIP, Ansicht folgt)\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_01PFUioZ3CbJFXvrcqAMyLYq\n' "${new:-Modelle}" > $W6/msg_auto.txt
			git commit -q -F $W6/msg_auto.txt && for i in 1 2 3 4; do git push -q origin wip-v080-welle6:wip/v080-welle6 > /dev/null 2>&1 && break; sleep $((i*5)); done
			echo "$(date +%T) AUTOCOMMIT $(git log --oneline -1)" >> $W6/logs/autocommit.log
		fi
	fi
	grep -q "QUEUE C1 DONE" $W6/logs/queue_c1.log && break
	sleep 15
done
echo "AUTOCOMMIT DONE $(date +%T)" >> $W6/logs/autocommit.log
