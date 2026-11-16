#!/bin/bash
# QA-M2-BILD chunk D (< 2 h): performance drives Kiel – Hamburg ganz (Autopilot, 12 Uhr, Limousine, Seed 11,
# --timescale=2 = 8 physics steps per frame, as M1 QA-BILD measured the ZS1 line): Modern medium, Modern low, Arcade.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
SH=$S/sh
Q=$S/logs/queue_perf.log
log() { echo "$(date -u +%H:%M:%S) $*" >> $Q; }
log "chunkD start"
KH="--stage=kiel_hamburg --from=kiel --timescale=2 --max-wall=6000 --sample=5"
DRIVE_TIMEOUT=4000 $SH/drive.sh m2 kh_m2_medium modern medium $KH >> $Q 2>&1
DRIVE_TIMEOUT=1800 $SH/drive.sh m2 kh_m2_low modern low $KH >> $Q 2>&1
DRIVE_TIMEOUT=1200 $SH/drive.sh m2 kh_arcade arcade - $KH >> $Q 2>&1
log "chunkD end"
