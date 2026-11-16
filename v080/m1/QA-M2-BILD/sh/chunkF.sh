#!/bin/bash
# QA-M2-BILD chunk F (< 2 h): vegetation levels (prop_scene), S1 at dawn and dusk, two 15-s A/B clips.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
SH=$S/sh
Q=$S/logs/queue_perf.log
log() { echo "$(date -u +%H:%M:%S) $*" >> $Q; }
log "chunkF start"
$SH/veg.sh >> $Q 2>&1
$SH/extra.sh >> $Q 2>&1
$SH/clips.sh >> $Q 2>&1
log "chunkF end"
