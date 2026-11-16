#!/bin/bash
# QA-BILD queue part d (replaces queue_c after the medium drive): high drive (time scale 4), Arcade drive, memory drive.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-BILD
Q=$S/queue.log
log() { echo "$(date +%H:%M:%S) $*" >> $Q; }
WAITPID=${1:-0}
log "queue_d start (waiting for pid $WAITPID)"
while [ "$WAITPID" != "0" ] && kill -0 "$WAITPID" 2>/dev/null; do sleep 5; done
log "medium drive finished"
P=(--stage=kiel_hamburg --from=kiel --hour=12 --vehicle=limousine --seed=11 --max-wall=2400 --sample=5)
$S/tools/drive.sh kh_modern_high modern high "${P[@]}" --timescale=4 --max-steps=64 >> $Q 2>&1
$S/tools/drive.sh kh_arcade arcade - "${P[@]}" --timescale=2 --max-steps=32 >> $Q 2>&1
log "perf done"
DRIVE_TIMEOUT=3000 $S/tools/drive.sh mem_modern_medium modern medium --stage=luettich_paris --from=luettich --hour=12 \
	--vehicle=limousine --seed=21 --timescale=8 --max-steps=128 --max-wall=2700 --sample=10 --quit-sim=1200 >> $Q 2>&1
log "memory done"
log "queue end"
