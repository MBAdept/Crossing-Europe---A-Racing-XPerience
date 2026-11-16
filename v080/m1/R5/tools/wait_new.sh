#!/usr/bin/env bash
# wait_new.sh <log> <pattern> – waits until the batch log has a line matching the pattern (or the batch ended), prints the tail
LOG=$1
PAT=$2
until grep -q "$PAT" "$LOG" 2>/dev/null || grep -q "BATCH2_DONE\|BATCH3_DONE" "$LOG" 2>/dev/null; do sleep 5; done
grep -v "^/tmp" "$LOG" | tail -3
