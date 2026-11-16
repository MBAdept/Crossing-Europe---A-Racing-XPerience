#!/bin/bash
# QA-M2-BILD: A/B series – Arcade, Modern M2 (6e48405) and Modern ZS1 (39849f0) of the same simulation state.
# Idempotent: a job whose pictures exist is skipped. Log: logs/queue_ab.log
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
log "queue_ab start"
for P in S0 S4 N1 S1 C1 N2 T1 T4 T3 T2 S2 S3 S5 U1 DEV; do
	A=$($SH/pos.sh $P)
	T="--shot-times=3"
	[ "$P" = S0 ] && T="--shot-times=1,4.5"
	job m2 arcade "${P}_arcade" 1280x720 "" $A $T
	job m2 modern "${P}_m2med" 1280x720 "--gfx-preset=medium" $A $T
	job zs1 modern "${P}_zs1med" 1280x720 "--gfx-preset=medium" $A $T
	job m2 modern "${P}_m2high" 1280x720 "--gfx-preset=high" $A $T
done
for P in S1 N1 C1; do
	A=$($SH/pos.sh $P)
	job m2 arcade "${P}_deckarcade" 1280x800 "" $A --shot-times=3
	job m2 modern "${P}_m2deck" 1280x800 "--gfx-preset=deck" $A --shot-times=3
	job zs1 modern "${P}_zs1deck" 1280x800 "--gfx-preset=deck" $A --shot-times=3
done
log "queue_ab end"
