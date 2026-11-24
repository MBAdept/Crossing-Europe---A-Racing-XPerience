#!/bin/bash
# chain 1 (lead, after the perf queue): Kiel – Hamburg deck at time-lapse 4 (first 150 s, closer to the game) head and
# base; then the gates one after the other; then the A-17 occlusion probe head/base
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3
until grep -q 'QUEUE-PERF DONE' $S/logs/queue_perf.log; do sleep 30; done
for t in head base; do MAXS=150 $S/sh/perf.sh kh4_deck_$t $t deck kiel_hamburg 12 normal 7 4 --from=kiel; done
echo "TS4 DONE $(date +%T)"
$S/sh/gates.sh import tests golden modernkeep sight validate keys geometry audio determinism ergebnis texmem render
echo "GATES1 DONE $(date +%T)"
$S/sh/occl.sh head T1 T2 T3 T4 C1 S0 S4
$S/sh/occl.sh base T1 T2 T3 T4 C1 S0 S4
echo "CHAIN1 DONE $(date +%T)"
