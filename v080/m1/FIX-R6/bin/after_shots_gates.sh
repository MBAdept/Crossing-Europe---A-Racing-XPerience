#!/usr/bin/env bash
# waits for the shot batch (shots2.sh), then runs the gate chain
until grep -q "deck_ziel_21 exit\|deck_ziel_21 skip" /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/tasks/b103h8psh.output 2>/dev/null; do sleep 15; done
exec bash /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R6/bin/gates.sh
