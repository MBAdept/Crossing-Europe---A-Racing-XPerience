#!/usr/bin/env bash
# wait until the noon A/B reached ho, stop chain1 (skip ks/wu at noon), then batch3
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a1
until grep -q "AB ho" $K/logs/abA.out || ! pgrep -f chain1.sh > /dev/null; do sleep 15; done
pkill -f chain1.sh; pkill -f ab_all.sh; sleep 2
pkill -f "ab/ks_high"; pkill -f "ab/wu_high"; sleep 5
echo "chain1 gestoppt $(date +%H:%M)"
$K/batch3.sh > $K/logs/batch3.out 2>&1
echo "=== chain3 fertig $(date +%H:%M)"
