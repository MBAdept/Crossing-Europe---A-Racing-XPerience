#!/bin/bash
# NACH-M2 queue 1: vehicle probe on head and base (sequential).
N=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-M2
L=$N/logs/q1.log
V=$N/sh/veh.sh
for h in 12 22; do
	$V head modern "nm2_h$h" --hour=$h --gfx-preset=medium --only=d20,d60,d150,player >> $L 2>&1
done
$V base modern "nb_h12" --hour=12 --gfx-preset=medium --only=d20,d60 >> $L 2>&1
$V base modern "nb_h22" --hour=22 --gfx-preset=medium --only=d20,d60 >> $L 2>&1
for spec in "limousine 12 normal" "sportwagen 19.5 normal" "kompakt 22 snow"; do
	set -- $spec
	$V head modern "pn_${1}" --hour=$2 --weather=$3 --vehicle=$1 --gfx-preset=medium --only=player_nobrake >> $L 2>&1
	$V base modern "pb_${1}" --hour=$2 --weather=$3 --vehicle=$1 --gfx-preset=medium --only=player_nobrake >> $L 2>&1
done
echo "$(date -u +%T) Q1-DONE" >> $L
