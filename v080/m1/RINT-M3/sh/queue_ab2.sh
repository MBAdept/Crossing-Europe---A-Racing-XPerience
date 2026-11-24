#!/bin/bash
# the rest of queue_ab.sh after the restart at 23:32 (KHH22 … T4 were done)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3
O=$S/shots/ab
$S/sh/shot.sh head $O/hoch high 3 C1 N1 N2 U1 DEV
$S/sh/shot.sh head $O/hoch high 2,4 MUC BEL HAN LYON NUE KHH KHH195 KIEL KIEL195 KIEL22
$S/sh/shot.sh head $O/hoch high 1,2 ROOF
$S/sh/shot.sh head $O/hoch high 1 HHA HHA22 DOF22
$S/sh/shot.sh head $O/hoch high 1,2.6,3.4 VAL VALN
$S/sh/shot.sh head $O/hoch high 1.5,2.5 TS15 TS15N
$S/sh/shot.sh head $O/deck deck 3 S1 N2 T2
$S/sh/shot.sh head $O/deck deck 1,2.6,3.4 VAL
$S/sh/shot.sh head $O/mittel medium 1.5 S0
$S/sh/shot.sh head $O/mittel medium 3 S1 S2 S3 S4 S5 T1 T2 T3 T4 C1 N1 N2 U1 DEV
echo "QUEUE-AB DONE $(date +%T)"
