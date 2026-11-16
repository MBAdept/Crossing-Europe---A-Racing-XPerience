#!/usr/bin/env bash
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a1
while pgrep -f batch1.sh > /dev/null; do sleep 10; done
$K/batch2.sh > $K/logs/batch2.out 2>&1
$K/ab_all.sh "hh:high:12 nu:high:12 hn:high:12 mu:high:12 ho:high:12 ks:high:12 wu:high:12" > $K/logs/abA.out 2>&1
echo "=== chain1 fertig $(date +%H:%M)"
