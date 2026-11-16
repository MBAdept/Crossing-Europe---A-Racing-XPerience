#!/bin/bash
# Sequential queue of the heavy QA jobs (one at a time). Progress in queue.log; each job's own output in <job>.out.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
JOBS=${*:-"fallback golden_spot quit_restart bench sound_caps"}
for j in $JOBS; do
	echo "START $j $(date +%T)" >> "$S/queue.log"
	bash "$S/bin/$j.sh" > "$S/$j.out" 2>&1
	echo "END $j $(date +%T) exit=$?" >> "$S/queue.log"
done
echo "QUEUE DONE $(date +%T)" >> "$S/queue.log"
