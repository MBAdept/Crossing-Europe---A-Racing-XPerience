#!/bin/bash
# R7D final round (resumable) on 6092197, slot B: base shots (if any left), the A/B pictures and clips on the head, the
# occlusion probe on the head, goldens, sight, ERGEBNIS
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7D
G=$S/gates
while pgrep -f "R7D/sh/queue_base.sh" > /dev/null; do sleep 30; done
grep -q 'QUEUE-BASE DONE' $S/logs/queue_base.log 2>/dev/null || $S/sh/queue_base.sh
$S/sh/queue_ab.sh a; $S/sh/queue_ab.sh b; $S/sh/queue_ab.sh c
grep -q "clip freie_strecke_daemmerung exit" $S/logs/queue_clips3.log 2>/dev/null || $S/sh/queue_clips.sh >> $S/logs/queue_clips3.log 2>&1
for p in T1 T2 T3 T4 C1 S0 S4; do
	grep -qE "occl head $p exit" $S/logs/occl3.log 2>/dev/null && continue
	$S/sh/occl.sh head $p >> $S/logs/occl3.log 2>&1
done
python3 $S/sh/occl_cmp.py $S/occl > $G/occl_cmp.txt 2>&1
for st in golden modernkeep sight ergebnis; do
	grep -q "gate $st fertig" $S/logs/gates3.log 2>/dev/null && continue
	$S/sh/gates.sh $st && echo "gate $st fertig" >> $S/logs/gates3.log
done
echo "SLOT3B DONE $(date +%T)" >> $G/summary.txt
