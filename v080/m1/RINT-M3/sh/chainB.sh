#!/bin/bash
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3
bash $S/sh/queue_ab2.sh >> $S/logs/queue_ab.log 2>&1
bash $S/sh/queue_clips.sh > $S/logs/queue_clips.log 2>&1
echo "CHAINB DONE $(date +%T)"
