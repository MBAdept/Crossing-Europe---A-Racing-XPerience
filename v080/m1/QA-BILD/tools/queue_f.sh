#!/bin/bash
# QA-BILD queue part f (replaces queue_e): high preset on the city end of Kiel–Hamburg (km 78 -> finish), Arcade
# complete drive, memory drive, then "queue end".
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-BILD
Q=$S/queue.log
log() { echo "$(date +%H:%M:%S) $*" >> $Q; }
log "queue_f start"
P=(--stage=kiel_hamburg --from=kiel --hour=12 --vehicle=limousine --seed=11 --max-wall=2400 --sample=5)
$S/tools/drive.sh kh_modern_high_city modern high "${P[@]}" --timescale=2 --start-km=78 --start-speed=50 >> $Q 2>&1
$S/tools/drive.sh kh_arcade arcade - "${P[@]}" --timescale=2 >> $Q 2>&1
log "perf done"
DRIVE_TIMEOUT=3000 $S/tools/drive.sh mem_modern_medium modern medium --stage=luettich_paris --from=luettich --hour=12 \
	--vehicle=limousine --seed=21 --timescale=32 --max-wall=2700 --sample=10 --quit-sim=1200 >> $Q 2>&1
log "memory done"
log "queue end"
