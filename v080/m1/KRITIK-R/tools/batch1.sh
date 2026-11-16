#!/bin/bash
# KRITIK-R batch 1: plan A and plan B on both trees, one after the other.
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R
for step in "after plan_a A" "before plan_a A" "after plan_b B" "before plan_b B"; do
	set -- $step
	echo "=== $1 $2 $(date +%T)"
	bash "$K/tools/run_cap.sh" "$1" "$K/tools/$2.json" "$3"
done
echo "=== batch1 fertig $(date +%T)"
