#!/bin/bash
# QA-BILD job queue, second half of queue.sh with shorter clips (replaces queue.sh from the S1 Arcade clip on).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-BILD
Q=$S/queue.log
log() { echo "$(date +%H:%M:%S) $*" >> $Q; }
log "queue_b start (waiting for the S1 Modern clip)"
while pgrep -f "s1_modern_high.avi" > /dev/null; do sleep 5; done
log "s1 modern clip finished"
FLY="--autopilot --autopilot-refuel=never --traffic-warmup --no-countdown"
A=(--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 $FLY --start-speed=120 --start-km=2)
$S/tools/clip.sh $S/clips/s1_arcade.avi arcade 840 - "${A[@]}" >> $Q 2>&1
B=(--stage=saragossa_pau --from=saragossa --start-km=198.8 --hour=11 --weather=normal --vehicle=kompakt --seed=4 $FLY --start-speed=80)
$S/tools/clip.sh $S/clips/t4_modern_med.avi modern 640 medium "${B[@]}" >> $Q 2>&1
$S/tools/clip.sh $S/clips/t4_arcade.avi arcade 600 - "${B[@]}" >> $Q 2>&1
C=(--stage=hamburg_hannover --from=hamburg --start-km=71 --hour=22 --weather=snow --vehicle=kompakt --seed=13 $FLY --start-speed=100)
$S/tools/clip.sh $S/clips/n1_modern_med.avi modern 640 medium "${C[@]}" >> $Q 2>&1
$S/tools/clip.sh $S/clips/n1_arcade.avi arcade 600 - "${C[@]}" >> $Q 2>&1
log "clips done"
P=(--stage=kiel_hamburg --from=kiel --hour=12 --vehicle=limousine --seed=11 --timescale=1 --max-wall=2400 --sample=5)
for pr in low medium high; do
	$S/tools/drive.sh kh_modern_$pr modern $pr "${P[@]}" >> $Q 2>&1
done
$S/tools/drive.sh kh_arcade arcade - "${P[@]}" >> $Q 2>&1
log "perf done"
DRIVE_TIMEOUT=3000 $S/tools/drive.sh mem_modern_medium modern medium --stage=luettich_paris --from=luettich --hour=12 \
	--vehicle=limousine --seed=21 --timescale=4 --max-steps=32 --max-wall=2700 --sample=10 --quit-sim=1200 >> $Q 2>&1
log "memory done"
log "queue end"
