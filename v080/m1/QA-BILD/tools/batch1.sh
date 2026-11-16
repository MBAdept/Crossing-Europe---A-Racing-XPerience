#!/bin/bash
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-BILD
$S/tools/ab.sh $S/ab_med medium S3 S4 S5 T1 T2 T3 T4 C1 N1 N2 U1 DEV -- --shot-times=2,6 > $S/ab_med/batch1.log 2>&1
echo DONE >> $S/ab_med/batch1.log
