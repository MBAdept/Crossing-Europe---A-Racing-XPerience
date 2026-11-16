#!/bin/bash
# KRITIK-R2-MESS batch 1: character (plan B) on obj and c1, slab sweep (plan S) on obj, r, c1. One after the other.
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R2-MESS
T=$W/tools
steps=${*:-Bobj Bc1 Sobj Sr Sc1}
for s in $steps; do
	echo "=== $s $(date +%T)"
	case $s in
		Bobj) bash $T/run_cap.sh obj $T/plan_mB.json B --seed=7101 ;;
		Bc1) bash $T/run_cap.sh c1 $T/plan_mB.json B --seed=7101 ;;
		Sobj) bash $T/run_cap.sh obj $T/plan_mS.json S --seed=7201 ;;
		Sr) bash $T/run_cap.sh r $T/plan_mS.json S --seed=7201 ;;
		Sc1) bash $T/run_cap.sh c1 $T/plan_mS.json S --seed=7201 ;;
	esac
done
echo "=== batch1 fertig $(date +%T)"
