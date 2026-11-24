#!/bin/bash
# R7D chain 3 (resumable): after the A/B queue part a – parts b and c, the clips, then chain 2
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7D
while pgrep -f "queue_ab.sh a" > /dev/null; do sleep 30; done
$S/sh/queue_ab.sh a
$S/sh/queue_ab.sh b
$S/sh/queue_ab.sh c
$S/sh/queue_clips.sh >> $S/logs/queue_clips.log 2>&1
$S/sh/chain2.sh >> $S/logs/chain2.log 2>&1
echo "CHAIN3 DONE $(date +%T)" >> $S/gates/summary.txt
