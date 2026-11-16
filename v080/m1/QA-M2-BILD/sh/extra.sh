#!/bin/bash
# QA-M2-BILD: light at more hours – S1 (Kiel – Hamburg km 2) at 6:30, 8:00, 17:30 and 20:30 in Arcade and Modern high;
# and B1 (river bridge arrival, Köln) – idempotent like queue_ab4's jobs. Log: logs/queue_ab.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
SH=$S/sh
Q=$S/logs/queue_ab.log
log() { echo "$(date -u +%H:%M:%S) $*" >> $Q; }
job() {   # job <tree> <mode> <name> <screen> <gfx> <args...>
	local tree=$1 mode=$2 name=$3 screen=$4 gfx=$5
	shift 5
	local d=$S/shots/${name%%_*}
	mkdir -p "$d"
	if ls "$d/${name}"_[0-9][0-9].png > /dev/null 2>&1; then log "skip $name"; return; fi
	log "start $name"
	SCREEN=$screen GFX="$gfx" $SH/shot.sh "$tree" "$mode" "$d/$name" "$@" >> $Q 2>&1
}
A=$($SH/pos.sh S1)
for h in 6.5 20.5; do
	hh=${h/./}
	job m2 arcade "H${hh}_arcade" 1280x720 "" $A --hour=$h --shot-times=3
	job m2 modern "H${hh}_m2high" 1280x720 "--gfx-preset=high" $A --hour=$h --shot-times=3
done
log "extra done"
