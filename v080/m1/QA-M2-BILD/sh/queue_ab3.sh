#!/bin/bash
# QA-M2-BILD: A/B series (machine under load 15+, so reduced):
#  1 S0 start: arcade, M2 medium, ZS1 medium (shot 1 s countdown, 4.5 s after LOS)
#  2 S4 Köhlbrand end: arcade, M2 high, ZS1 high
#  3 every other position: arcade + M2 high (ZS1 high = gate1 "hoch" pictures, same code at these positions)
#  4 vehicle probe (sh/vehicles.sh)
#  5 Steam Deck 1280x800: S1, N1 – arcade, M2 deck, ZS1 deck;  6 M2 medium S1 N1 C1 T4
# Idempotent; waits until no other shot.sh runs. Log: logs/queue_ab.log
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
log "queue_ab3 start"
A=$($SH/pos.sh S0)
job m2 arcade S0_arcade 1280x720 "" $A --shot-times=1,4.5
job m2 modern S0_m2med 1280x720 "--gfx-preset=medium" $A --shot-times=1,4.5
job zs1 modern S0_zs1med 1280x720 "--gfx-preset=medium" $A --shot-times=1,4.5
A=$($SH/pos.sh S4)
job m2 arcade S4_arcade 1280x720 "" $A --shot-times=3
job m2 modern S4_m2high 1280x720 "--gfx-preset=high" $A --shot-times=3
job zs1 modern S4_zs1high 1280x720 "--gfx-preset=high" $A --shot-times=3
for P in N1 S1 C1 N2 T1 T4 T3 T2 S2 S3 S5 U1 DEV; do
	A=$($SH/pos.sh $P)
	job m2 arcade "${P}_arcade" 1280x720 "" $A --shot-times=3
	job m2 modern "${P}_m2high" 1280x720 "--gfx-preset=high" $A --shot-times=3
done
log "pass3 done"
$SH/vehicles.sh >> $Q 2>&1
log "vehicles done"
for P in S1 N1; do
	A=$($SH/pos.sh $P)
	job m2 arcade "${P}_deckarcade" 1280x800 "" $A --shot-times=3
	job m2 modern "${P}_m2deck" 1280x800 "--gfx-preset=deck" $A --shot-times=3
	job zs1 modern "${P}_zs1deck" 1280x800 "--gfx-preset=deck" $A --shot-times=3
done
for P in S1 N1 C1 T4; do
	A=$($SH/pos.sh $P)
	job m2 modern "${P}_m2med" 1280x720 "--gfx-preset=medium" $A --shot-times=3
done
log "queue_ab3 end"
