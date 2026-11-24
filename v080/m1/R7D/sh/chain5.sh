#!/bin/bash
# R7D chain 5 (resumable, after the container restart): Modern at the base for the base | head sheets, S1/S3 again on
# the final head, then the perf rounds 2 and 3 and the sky-off runs on a quiet machine
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7D
grep -q 'QUEUE-BASE DONE' $S/logs/queue_base.log 2>/dev/null || $S/sh/queue_base.sh
grep -q 'HEAD2 DONE' $S/logs/head2.log 2>/dev/null || $S/sh/head2.sh
grep -q 'PERF2 DONE' $S/logs/perf2.log 2>/dev/null || $S/sh/perf2.sh
echo "CHAIN5 DONE $(date +%T)" >> $S/gates/summary.txt
