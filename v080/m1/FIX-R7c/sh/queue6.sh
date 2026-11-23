#!/bin/bash
# FIX-R7c queue 6 (final head): Arcade goldens once, the second full test run, then test_props in the merges with
# FIX-RINT and FIX-R7a (trees exported by the caller as m1/FIX-R7c/mt_<name>.tar).
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c/sh/common.sh
echo "Q6 start $(date -u +%H:%M:%S)" >> "$S/logs/queue.out"
cd "$WT" || exit 1
memwait
XDG_DATA_HOME=$S/xdg_golden nice -n 10 tools/golden.sh check > "$S/gates/golden_check.log" 2>&1
echo "Q6 golden exit=$? $(grep -E 'GOLDEN' "$S/gates/golden_check.log" | tr '\n' ' ')" >> "$S/logs/queue.out"
memwait
XDG_DATA_HOME=$S/xdg_gate2 nice -n 10 tools/run_tests.sh > "$S/gates/run_tests_2.log" 2>&1
echo "Q6 run_tests exit=$? $(grep -E 'Tests, |Tests bestanden' "$S/gates/run_tests_2.log" | tr '\n' ' ')" >> "$S/logs/queue.out"
for n in fixrint fixr7a; do
	if [ -s "$S/mt_$n.tar" ]; then
		memwait
		"$S/sh/mergetest.sh" "$n" >> "$S/logs/queue.out" 2>&1
	fi
done
echo "Q6 DONE $(date -u +%H:%M:%S)" >> "$S/logs/queue.out"
