#!/usr/bin/env bash
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a1
while pgrep -f chain1.sh > /dev/null; do sleep 15; done
$K/batch3.sh > $K/logs/batch3.out 2>&1
echo "=== chain2 fertig $(date +%H:%M)"
