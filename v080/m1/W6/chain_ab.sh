#!/bin/bash
# W6: one A/B chain (rest of C1, then C2) next to the landmark exports - at most 2 heavy jobs
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
bash $W6/ab.sh $W6/ab_c1.txt ab_c1
bash $W6/ab.sh $W6/ab_c2.txt ab_c2
