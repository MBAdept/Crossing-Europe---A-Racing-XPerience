#!/usr/bin/env bash
# R7c: modern-check on the final head (after modern-make)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c/env.sh
cd "$WT"
G=$S/gates
waitmem
mkdir -p "$S/tmp_golden"
TMPDIR=$S/tmp_golden nice -n 10 tools/golden.sh modern-check > "$G/final_modern_check.log" 2>&1
echo "$(date +%H:%M) modern-check final exit $? – $(grep -E 'GOLDEN' $G/final_modern_check.log | tr '\n' ' ')" >> "$G/summary.txt"
