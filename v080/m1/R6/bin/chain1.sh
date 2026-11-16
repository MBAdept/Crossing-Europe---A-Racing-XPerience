#!/usr/bin/env bash
# R6: the heavy jobs one after the other – the two render checks that failed in run 1 (flash, fascia), then the A/B
# pictures of batch 2 (the clips follow as a job of their own: a background job may run at most 2 h).
B=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R6/bin
O=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R6/shots
echo "== rc blitz $(date +%H:%M)"
"$B/rc_structures.sh" check_structures blitz > "$O/rc2_blitz.log" 2>&1
grep -E "^RENDER-CHECK|^exit" "$O/rc2_blitz.log"
echo "== rc tankstelle $(date +%H:%M)"
"$B/rc_structures.sh" check_structures_licht tankstelle > "$O/rc2_tankstelle.log" 2>&1
grep -E "^RENDER-CHECK|^exit" "$O/rc2_tankstelle.log"
echo "== batch2 $(date +%H:%M)"
"$B/batch2.sh"
echo "CHAIN1 DONE $(date +%H:%M)"
