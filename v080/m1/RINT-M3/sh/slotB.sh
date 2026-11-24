#!/bin/bash
# resumable: the rest of the A/B queue (a position counts as done when its first A/B picture exists), then the clips
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3
O=$S/shots/ab
run() {   # run <dir> <preset> <times> <pos…>
	local d=$1 pre=$2 st=$3; shift 3
	for p in "$@"; do
		[ -f $O/$d/${p}_${pre}_ab_00.jpg ] && continue
		rm -f $O/$d/${p}_${pre}*
		$S/sh/shot.sh head $O/$d $pre $st $p >> $S/logs/queue_ab.log 2>&1
	done
}
run hoch high 2,4 NUE KHH KHH195 KIEL KIEL195 KIEL22
run hoch high 1,2 ROOF
run hoch high 1 HHA HHA22 DOF22
run hoch high 1,2.6,3.4 VAL VALN
run hoch high 1.5,2.5 TS15 TS15N
run deck deck 3 S1 N2 T2
run deck deck 1,2.6,3.4 VAL
run mittel medium 1.5 S0
run mittel medium 3 S1 S2 S3 S4 S5 T1 T2 T3 T4 C1 N1 N2 U1 DEV
echo "QUEUE-AB DONE $(date +%T)" >> $S/logs/queue_ab.log
bash $S/sh/queue_clips2.sh >> $S/logs/queue_clips.log 2>&1
echo "SLOTB DONE $(date +%T)"
