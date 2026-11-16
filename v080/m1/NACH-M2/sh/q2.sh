#!/bin/bash
# NACH-M2 queue 2: A/B positions on head (QA-M2-BILD positions), after q1.
N=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-M2
POS=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD/sh/pos.sh
L=$N/logs/q2.log
while ! grep -q Q1-DONE $N/logs/q1.log 2>/dev/null; do sleep 20; done
mkdir -p $N/shots/ab
job() {  # job <tree> <mode> <name> <gfx> <pos> <args…>
	local tree=$1 mode=$2 name=$3 gfx=$4 p=$5
	shift 5
	if ls "$N/shots/ab/${name}"_[0-9][0-9].png > /dev/null 2>&1; then echo "skip $name" >> $L; return; fi
	GFX="$gfx" $N/sh/shot.sh $tree $mode "$N/shots/ab/$name" $($POS $p) "$@" >> $L 2>&1
}
job head modern S0_nm2med "--gfx-preset=medium" S0 --shot-times=1,4.5
job base modern S0_nbmed "--gfx-preset=medium" S0 --shot-times=1,4.5
job head modern S1_nm2high "--gfx-preset=high" S1 --shot-times=3
job head modern C1_nm2high "--gfx-preset=high" C1 --shot-times=3
job head modern N1_nm2high "--gfx-preset=high" N1 --shot-times=3
job head modern KBT_nm2high "--gfx-preset=high" KBT --shot-times=2,4
job head modern KBN_nm2high "--gfx-preset=high" KBN --shot-times=2,4
echo "$(date -u +%T) Q2-DONE" >> $L
