#!/usr/bin/env bash
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a1
while pgrep -f chain4.sh > /dev/null; do sleep 15; done
SHOTS=2,4 $K/ab_all.sh "hh:high:22 nu:high:22" > $K/logs/abB.out 2>&1
SHOTS=2 $K/ab_all.sh "hn:medium:19.5" >> $K/logs/abB.out 2>&1
echo "=== chain5 fertig $(date +%H:%M)"
