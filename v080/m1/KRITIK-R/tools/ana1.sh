#!/bin/bash
# KRITIK-R: analysis of batch 1 (one after the other, nice 19)
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R
cd "$K/tools" || exit 2
for t in after before; do
	for p in A B; do
		nice -n 19 python3 -I ana_cap.py "$K/cap/$t/$p" "$K/res/${p}_$t.json" > "$K/logs/ana_${p}_$t.txt" 2>&1
		echo "ana $p $t exit $?"
	done
done
nice -n 19 python3 -I ana_compare.py "$K/res/A_before.json" "$K/res/A_after.json" "$K/res/B_before.json" "$K/res/B_after.json" \
	"$K/res/compare.json" > "$K/logs/compare.txt" 2>&1
echo "compare exit $?"
nice -n 19 python3 -I ana_mod.py "$K/cap/before/A" "$K/cap/after/A" "$K/res/mod_A.json" asph130_road conc130_road cobbles50_road \
	asph130_wind asph130_full conc130_full > "$K/logs/mod_A.txt" 2>&1
echo "mod A exit $?"
nice -n 19 python3 -I ana_mod.py "$K/cap/before/B" "$K/cap/after/B" "$K/res/mod_B.json" c_asph130_road c_conc130_road c_conc130_slab \
	c_conc130_tyre c_cobbles50_road c_rumble130_road c_deck80_road c_wet130_road c_gravel100_road c_grass60_road c_wind130 c_wind200 \
	c_windvmax s_snow50_road s_snow90_road s_snow130_road > "$K/logs/mod_B.txt" 2>&1
echo "mod B exit $?"
