#!/bin/bash
# QA-M2-BILD chunk A (< 2 h, one background command): occlusion probe rest (T3, T1, W1 – Arcade + M2 high) and the
# positions N1 S1 C1 T1 at high (Arcade + M2). Idempotent. Log logs/queue_ab.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
SH=$S/sh
Q=$S/logs/queue_ab.log
log() { echo "$(date -u +%H:%M:%S) $*" >> $Q; }
. $SH/jobs.sh
log "chunkA start"
$SH/occl.sh >> $Q 2>&1
log "occl done"
for P in N1 S1 C1 T1; do
	A=$($SH/pos.sh $P)
	job m2 arcade "${P}_arcade" 1280x720 "" $A --shot-times=3
	job m2 modern "${P}_m2high" 1280x720 "--gfx-preset=high" $A --shot-times=3
done
log "chunkA end"
