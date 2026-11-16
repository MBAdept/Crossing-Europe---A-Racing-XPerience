#!/bin/bash
# QA-M2-BILD: A/B series, second order – pass 1: Arcade + Modern M2 medium + Modern ZS1 medium for every position;
# pass 2: vehicle probe; pass 3: M2 high; pass 4: deck 1280x800. Idempotent (a job whose pictures exist is skipped).
# Waits until no other shot.sh runs (one heavy job at a time). Log: logs/queue_ab.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
SH=$S/sh
Q=$S/logs/queue_ab.log
log() { echo "$(date -u +%H:%M:%S) $*" >> $Q; }
while pgrep -f "QA-M2-BILD/sh/shot.sh" > /dev/null; do sleep 5; done
job() {   # job <tree> <mode> <name> <screen> <gfx> <args...>
	local tree=$1 mode=$2 name=$3 screen=$4 gfx=$5
	shift 5
	local d=$S/shots/${name%%_*}
	mkdir -p "$d"
	local want=1
	case "$*" in *--shot-times=1,4.5*) want=2 ;; esac
	local have
	have=$(ls "$d/${name}"_[0-9][0-9].png 2> /dev/null | wc -l)
	if [ "$have" -ge "$want" ]; then log "skip $name"; return; fi
	log "start $name"
	SCREEN=$screen GFX="$gfx" $SH/shot.sh "$tree" "$mode" "$d/$name" "$@" >> $Q 2>&1
}
log "queue_ab2 start"
ALLP="S0 S4 N1 S1 C1 N2 T1 T4 T3 T2 S2 S3 S5 U1 DEV"
for P in $ALLP; do
	A=$($SH/pos.sh $P)
	T="--shot-times=3"
	[ "$P" = S0 ] && T="--shot-times=1,4.5"
	job m2 arcade "${P}_arcade" 1280x720 "" $A $T
	job m2 modern "${P}_m2med" 1280x720 "--gfx-preset=medium" $A $T
	job zs1 modern "${P}_zs1med" 1280x720 "--gfx-preset=medium" $A $T
done
log "pass1 done"
[ -x $SH/vehicles.sh ] && $SH/vehicles.sh >> $Q 2>&1
log "pass2 done"
for P in $ALLP; do
	A=$($SH/pos.sh $P)
	T="--shot-times=3"
	[ "$P" = S0 ] && T="--shot-times=1,4.5"
	job m2 modern "${P}_m2high" 1280x720 "--gfx-preset=high" $A $T
done
log "pass3 done"
for P in S1 N1 C1; do
	A=$($SH/pos.sh $P)
	job m2 arcade "${P}_deckarcade" 1280x800 "" $A --shot-times=3
	job m2 modern "${P}_m2deck" 1280x800 "--gfx-preset=deck" $A --shot-times=3
	job zs1 modern "${P}_zs1deck" 1280x800 "--gfx-preset=deck" $A --shot-times=3
done
log "queue_ab2 end"
