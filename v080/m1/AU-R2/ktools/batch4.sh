#!/bin/bash
# AU-R2 batch 4 (second verification round on the final assets): plan B3 (cobbles), plan A3 (cobbles, concrete 170,
# concrete 200 four times), then the analysis. nice 19, one after the other.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R2
K=$S/ktools
echo "=== b3 $(date +%T)"
bash "$K/run_cap.sh" after "$K/plan_b3.json" B3
echo "=== a3 $(date +%T)"
bash "$K/run_cap.sh" after "$K/plan_a3.json" A3
echo "=== ana $(date +%T)"
nice -n 19 python3 "$K/ana_cap.py" "$S/cap/after/B3" "$S/res/B3_after.json" > "$S/logs/ana_B3.txt" 2>&1
nice -n 19 python3 "$K/ana_cap.py" "$S/cap/after/A3" "$S/res/A3_after.json" > "$S/logs/ana_A3.txt" 2>&1
nice -n 19 python3 "$K/ana_peaks.py" "$S/cap/before/B/c_cobbles50_road.wav" "$S/cap/after/B3/c_cobbles50_road.wav" \
	"$S/res/peaks_cobbles3.json" > "$S/logs/peaks_cobbles3.txt" 2>&1
echo "=== batch4 fertig $(date +%T)"
