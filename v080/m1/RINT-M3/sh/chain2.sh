#!/bin/bash
# chain 2 (lead, after the time-lapse-4 runs): note 11 sprite re-render (20 min cap), note 9 and N-02 pictures, the A/B
# queue, the clips
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3
until grep -q 'TS4 DONE' $S/logs/chain1.log 2>/dev/null; do sleep 30; done
bash $S/sh/sprite_check.sh > $S/logs/sprite_check.log 2>&1
echo "SPRITE DONE $(date +%T)"
$S/sh/shot.sh head $S/shots/n02/head high 3.6,3.9,3.97,4.0,4.03 VALS
$S/sh/shot.sh base $S/shots/n02/base high 3.6,3.9,3.97,4.0,4.03 VALS
echo "N02 DONE $(date +%T)"
bash $S/sh/queue_ab.sh > $S/logs/queue_ab.log 2>&1
bash $S/sh/queue_clips.sh > $S/logs/queue_clips.log 2>&1
echo "CHAIN2 DONE $(date +%T)"
