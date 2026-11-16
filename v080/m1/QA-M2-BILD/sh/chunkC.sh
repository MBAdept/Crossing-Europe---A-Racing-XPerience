#!/bin/bash
# QA-M2-BILD chunk C (< 2 h): vehicle probe player cars, Steam Deck 1280x800 S1 (Arcade, M2 deck).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
SH=$S/sh
Q=$S/logs/queue_ab.log
log() { echo "$(date -u +%H:%M:%S) $*" >> $Q; }
. $SH/jobs.sh
log "chunkC start"
$SH/vehicles.sh player >> $Q 2>&1
A=$($SH/pos.sh S1)
job m2 arcade "S1_deckarcade" 1280x800 "" $A --shot-times=3
job m2 modern "S1_m2deck" 1280x800 "--gfx-preset=deck" $A --shot-times=3
log "chunkC end"
