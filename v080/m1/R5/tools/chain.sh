#!/usr/bin/env bash
# R5 successor 4: after batch 5, run batch 6, the gates and the perf runs one after the other (one heavy job at a time).
R5=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R5
until grep -q BATCH5_DONE $R5/batch5.log 2>/dev/null; do sleep 30; done
echo "batch5 done $(date +%H:%M)"
bash $R5/tools/batch6.sh > $R5/batch6.log 2>&1
echo "batch6 done $(date +%H:%M)"
bash $R5/tools/gates.sh import scripts tests golden modern_check render sight path > $R5/gates_run.log 2>&1
echo "gates done $(date +%H:%M)"
bash $R5/tools/perf.sh new > $R5/perf_new.log 2>&1
echo "perf new done $(date +%H:%M)"
bash $R5/tools/perf.sh base > $R5/perf_base.log 2>&1
echo "perf base done $(date +%H:%M)"
echo CHAIN_DONE
