#!/usr/bin/env bash
# R6 successor 3: gates A then gates B, one after the other (heavy jobs never in parallel).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R6
echo "chain3 start $(date +%H:%M)"
"$S/bin/gates_a.sh"
"$S/bin/gates_b.sh"
echo "CHAIN3 DONE $(date +%H:%M)"
