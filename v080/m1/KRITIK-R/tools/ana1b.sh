#!/bin/bash
# KRITIK-R: analysis of batch 1, plan B again (after the max-lag fix) and the comparison
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R
cd "$K/tools" || exit 2
for t in after before; do
	nice -n 19 python3 -I ana_cap.py "$K/cap/$t/B" "$K/res/B_$t.json" > "$K/logs/ana_B_$t.txt" 2>&1
	echo "ana B $t exit $?"
done
nice -n 19 python3 -I ana_compare.py "$K/res/A_before.json" "$K/res/A_after.json" "$K/res/B_before.json" "$K/res/B_after.json" \
	"$K/res/compare.json" > "$K/logs/compare.txt" 2>&1
echo "compare exit $?"
