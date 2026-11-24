#!/bin/bash
# R7D: Modern at the base (720eaf4) at every A/B position – for the base | head sheets (resumable)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7D
O=$S/shots/base_ab
run() {   # run <dir> <preset> <times> <pos…>
	local d=$1 pre=$2 st=$3; shift 3
	for p in "$@"; do
		[ -f $O/$d/${p}_${pre}_modern_00.png ] && continue
		rm -f $O/$d/${p}_${pre}*
		$S/sh/shot.sh base $O/$d $pre $st $p >> $S/logs/queue_base.log 2>&1
	done
}
run hoch high 3 S1M S1 S1D S1N S1R S1S S1RN B1 S3M S3 S3D S3N S3R S3S S3RN T2 S4
run hoch high 1.5 S0
run deck deck 3 S1
echo "QUEUE-BASE DONE $(date +%T)" >> $S/logs/queue_base.log
