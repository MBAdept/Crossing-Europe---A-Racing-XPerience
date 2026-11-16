#!/bin/bash
# QA-M2-BILD: performance drives and clips (after the picture queue). Kiel – Hamburg, Autopilot, 12 Uhr, Limousine,
# Seed 11, --timescale=2 (8 physics steps per frame, as M1 QA-BILD measured the ZS1 line) per preset; ZS1 tree at the
# same load (km 0–35); Arcade; a 22-min leak drive (Lüttich – Paris + Kiel – Hamburg chained, --timescale=32); cold
# warm-up checks; then three 15-s A/B clips. Idempotent. Log: logs/queue_perf.log
# Start early (skip the wait for the picture queue): touch logs/perf_now
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
SH=$S/sh
Q=$S/logs/queue_perf.log
log() { echo "$(date -u +%H:%M:%S) $*" >> $Q; }
busy() { pgrep -f "QA-M2-BILD/sh/shot.sh" > /dev/null || pgrep -f "QA-M2-BILD/probe/qa_" > /dev/null || pgrep -f "QA-M2-BILD/sh/queue_ab" > /dev/null; }
until grep -q "queue_ab3 end" $S/logs/queue_ab.log 2> /dev/null || [ -f $S/logs/perf_now ]; do sleep 20; done
while busy; do sleep 10; done
log "queue_perf start"
KH="--stage=kiel_hamburg --from=kiel --timescale=2 --max-wall=6000 --sample=5"
$SH/drive.sh m2 kh_m2_medium modern medium $KH >> $Q 2>&1
$SH/drive.sh m2 kh_m2_low modern low $KH >> $Q 2>&1
$SH/drive.sh zs1 kh_zs1_medium35 modern medium $KH --quit-km=35 >> $Q 2>&1
$SH/drive.sh m2 kh_m2_high35 modern high $KH --quit-km=35 >> $Q 2>&1
$SH/drive.sh m2 kh_arcade arcade - $KH >> $Q 2>&1
PROBE=$S/probe/qa_drive2.gd $SH/drive.sh m2 mem_m2_medium modern medium --stage=luettich_paris --from=luettich --seed=21 \
	--timescale=32 --sample=10 --max-wall=6000 --chain=kiel_hamburg:kiel >> $Q 2>&1
$SH/warm.sh >> $Q 2>&1
log "perf done"
$SH/veg.sh >> $Q 2>&1
log "veg done"
$SH/extra.sh >> $Q 2>&1
log "extra done"
$SH/clips.sh >> $Q 2>&1
log "queue_perf end"
