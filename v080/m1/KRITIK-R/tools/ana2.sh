#!/bin/bash
# KRITIK-R: analysis of batch 2 (one after the other, nice 19)
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R
KF=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-FAHRBAHN
cd "$K/tools" || exit 2
steps=${*:-trig shares slab crash worst}
for s in $steps; do
	case $s in
		trig)
			for st in kiel_hamburg mailand_venedig luettich_paris bern_mailand; do
				nice -n 19 python3 -I ana_trigger.py "$KF/logs/trig_$st.log" > "$K/logs/trigana_before_$st.txt" 2>&1
				nice -n 19 python3 -I ana_trigger.py "$K/logs/trig_$st.log" > "$K/logs/trigana_after_$st.txt" 2>&1
				echo "trig $st exit $?"
			done ;;
		shares)
			nice -n 19 python3 -I ana_shares.py "$K/logs/shares_before.log" "$K/logs/shares_after.log" "$K/res/shares.json" > "$K/logs/shares_ana.txt" 2>&1
			echo "shares exit $?" ;;
		slab)
			for t in after before; do
				nice -n 19 python3 -I ana_slab.py "$K/cap/slab/$t" "$K/res/slab_$t.json" > "$K/logs/slab_ana_$t.txt" 2>&1
				echo "slab $t exit $?"
			done ;;
		crash)
			for c in after_car after_truck afterold_car afterold_truck before_car before_truck; do
				nice -n 19 python3 -I ana_crash.py crash "$K/cap/crash/$c.wav" "$K/res/crash_$c.json" > "$K/logs/crash_ana_$c.txt" 2>&1
				echo "crash $c exit $?"
			done ;;
		worst)
			for t in after before; do
				nice -n 19 python3 -I ana_crash.py worst "$K/cap/worst/$t.wav" "$K/res/worst_$t.json" > "$K/logs/worst_ana_$t.txt" 2>&1
				echo "worst $t exit $?"
			done ;;
	esac
done
