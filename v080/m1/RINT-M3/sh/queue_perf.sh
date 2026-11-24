#!/bin/bash
# perf queue: Kiel–Hamburg deck and medium, head and base interleaved, three runs each; then a stage with a tunnel and a
# city finish (Prag – Nürnberg from km 80: Tunel Valík, finish in Nürnberg), head and base
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3
for r in 1 2 3; do
  for p in deck medium; do
    for t in head base; do
      $S/sh/perf.sh kh_${p}_${t}_$r $t $p kiel_hamburg 12 normal 7 16 --from=kiel
    done
  done
done
for t in head base; do
  $S/sh/perf.sh pn_medium_${t} $t medium prag_nuernberg 12 normal 7 16 --from=prag --start-km=80
done
echo "QUEUE-PERF DONE $(date +%T)"
