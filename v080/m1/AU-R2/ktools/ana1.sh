#!/bin/bash
# AU-R2: analysis of batch 1 (one after the other, nice 19): ana_cap per capture, the before/after tables
# (ana_compare), per-channel peaks of the cobbles (M5).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R2
K=$S/ktools
mkdir -p "$S/res"
for t in after before; do
	for p in B A; do
		[ -f "$S/cap/$t/$p/segments.json" ] && nice -n 19 python3 "$K/ana_cap.py" "$S/cap/$t/$p" "$S/res/${p}_$t.json" > "$S/logs/ana_${p}_$t.txt" 2>&1
		echo "ana $p $t exit $?"
	done
done
[ -f "$S/cap/after/M3/segments.json" ] && nice -n 19 python3 "$K/ana_cap.py" "$S/cap/after/M3" "$S/res/M3_after.json" > "$S/logs/ana_M3.txt" 2>&1
[ -f "$S/cap/after/M3B/segments.json" ] && nice -n 19 python3 "$K/ana_cap.py" "$S/cap/after/M3B" "$S/res/M3B_after.json" > "$S/logs/ana_M3B.txt" 2>&1
nice -n 19 python3 "$K/ana_compare.py" "$S/res/A_before.json" "$S/res/A_after.json" "$S/res/B_before.json" "$S/res/B_after.json" \
	"$S/res/compare.json" > "$S/logs/compare.txt" 2>&1
echo "compare exit $?"
nice -n 19 python3 "$K/ana_peaks.py" "$S/cap/before/B/c_cobbles50_road.wav" "$S/cap/after/B/c_cobbles50_road.wav" \
	"$S/res/peaks_cobbles.json" > "$S/logs/peaks_cobbles.txt" 2>&1
echo "peaks exit $?"
