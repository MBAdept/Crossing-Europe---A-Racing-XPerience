#!/bin/bash
# W6: race A/B of the L1 landmarks, after the C2 A/B chain and the L1 exports
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
until grep -q "AB DONE" $W6/logs/ab_c2.log 2>/dev/null && grep -q "QUEUE L1 DONE" $W6/logs/queue_l1.log; do sleep 30; done
bash $W6/ab.sh $W6/ab_lm1.txt ab_lm1
