#!/bin/bash
# queue6.sh – after queue5: import + check_scripts (gates), then the tunnel exit again (shots/v6)
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
until grep -q QUEUE_DONE "$R4/shots/v5/queue.log" 2>/dev/null; do sleep 20; done
"$R4/sh/gates.sh" import check_scripts
QUEUE="TEXIT ${QUEUE6_EXTRA:-}" "$R4/sh/queue5.sh" "$R4/shots/v6"
echo QUEUE6_DONE >> "$R4/shots/v6/queue.log"
