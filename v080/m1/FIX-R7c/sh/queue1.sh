#!/bin/bash
# FIX-R7c queue 1: the pictures of the findings, then the rest of the look check, then perf (one heavy job at a time)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c
echo "Q1 start $(date -u +%H:%M:%S)" >> "$S/logs/queue.out"
"$S/sh/pics.sh" hh:deck:12 start_deck nu:high:12
echo "Q1 findings pictures done $(date -u +%H:%M:%S)" >> "$S/logs/queue.out"
"$S/sh/pics.sh" nu:deck:12 pa:deck:12 hh:high:12 start_high pa:high:12 am:high:12
echo "Q1 pictures done $(date -u +%H:%M:%S)" >> "$S/logs/queue.out"
"$S/sh/perf.sh"
echo "Q1 DONE $(date -u +%H:%M:%S)" >> "$S/logs/queue.out"
