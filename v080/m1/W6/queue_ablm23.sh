#!/bin/bash
# W6: race A/B of the L2 and L3 landmarks, after ab_lm1 and all L2/L3 exports
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
until grep -q "AB DONE" $W6/logs/ab_lm1.log 2>/dev/null && grep -q "QUEUE L2 DONE" $W6/logs/queue_l2.log; do sleep 30; done
bash $W6/ab.sh $W6/ab_lm2.txt ab_lm2
bash $W6/ab.sh $W6/ab_lm3.txt ab_lm3
