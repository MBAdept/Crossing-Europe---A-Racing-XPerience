#!/bin/bash
# QA-M2-BILD chunk E (< 2 h): ZS1 medium on Kiel – Hamburg km 40–90 (where M2's medium drive had its streamer stalls,
# same load period), M2 high km 0–35, the 22-min leak drive (Lüttich – Paris + Kiel – Hamburg chained,
# --timescale=32), cold-cache warm-up checks.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
SH=$S/sh
Q=$S/logs/queue_perf.log
log() { echo "$(date -u +%H:%M:%S) $*" >> $Q; }
log "chunkE start"
KH="--stage=kiel_hamburg --from=kiel --timescale=2 --max-wall=6000 --sample=5"
DRIVE_TIMEOUT=2400 $SH/drive.sh zs1 kh_zs1_medium4090 modern medium $KH --start-km=40 --start-speed=120 --quit-km=90 >> $Q 2>&1
DRIVE_TIMEOUT=2000 $SH/drive.sh m2 kh_m2_high35 modern high $KH --quit-km=35 >> $Q 2>&1
PROBE=$S/probe/qa_drive2.gd DRIVE_TIMEOUT=2400 $SH/drive.sh m2 mem_m2_medium modern medium --stage=luettich_paris \
	--from=luettich --seed=21 --timescale=32 --sample=10 --max-wall=6000 --chain=kiel_hamburg:kiel >> $Q 2>&1
$SH/warm.sh >> $Q 2>&1
log "chunkE end"
