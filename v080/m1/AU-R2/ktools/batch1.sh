#!/bin/bash
# AU-R2 batch 1: the reviewer's captures (plans B2, A2, M3) on the AU-C1 copy (before) and the AU-R2 worktree
# (after), one after the other, nice 19.   batch1.sh [steps...]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R2
K=$S/ktools
steps=${*:-b2after b2before a2after a2before m3}
for s in $steps; do
	echo "=== $s $(date +%T)"
	case $s in
		b2after) bash "$K/run_cap.sh" after "$K/plan_b2.json" B ;;
		b2before) bash "$K/run_cap.sh" before "$K/plan_b2.json" B ;;
		a2after) bash "$K/run_cap.sh" after "$K/plan_a2.json" A ;;
		a2before) bash "$K/run_cap.sh" before "$K/plan_a2.json" A --only=conc130_full,conc130_noslab_full,cobbles50_full,cobbles50_road,conc170_full,conc200_full,asph130_full ;;
		m3) bash "$K/run_cap.sh" after "$K/plan_m3.json" M3 ;;
	esac
done
echo "=== batch1 fertig $(date +%T)"
