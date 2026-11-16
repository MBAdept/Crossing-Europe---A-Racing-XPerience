#!/bin/bash
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R4
L=$S/queue1.log
echo "start $(date +%T)" >> $L
$S/sh/ab.sh N2N_high N2N high --shot-times=2,4,6.2 >> $L 2>&1
$S/sh/mshot.sh base N2N_high N2N high --shot-times=2,4,6.2 >> $L 2>&1
$S/sh/ab.sh KBNR_high KBN high --weather=rain --shot-times=2,4,6 >> $L 2>&1
$S/sh/mshot.sh base KBNR_high KBN high --weather=rain --shot-times=2,4,6 >> $L 2>&1
$S/sh/ab.sh C1RN_high C1RN high --shot-times=2,4 >> $L 2>&1
$S/sh/mshot.sh base C1RN_high C1RN high --shot-times=2,4 >> $L 2>&1
echo "QUEUE1_DONE $(date +%T)" >> $L
