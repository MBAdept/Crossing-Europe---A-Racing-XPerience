#!/usr/bin/env bash
# R7c: the rest of the forest pictures (the first queue hit its time limit), then release chain2 (the gates)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c
"$S/queue.sh" wald > "$S/logs/queue1b.out" 2>&1
echo "$(date +%H:%M) queue fertig: lodcheck far078 (Rest wald)" >> "$S/gates/summary.txt"
