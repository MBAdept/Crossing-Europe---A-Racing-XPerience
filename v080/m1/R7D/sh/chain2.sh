#!/bin/bash
# R7D chain 2 (resumable): full test suite, occlusion probe head and base, goldens, sight, ERGEBNIS, perf
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7D/sh/env.sh
G=$S/gates; mkdir -p $G
cd $W
if ! grep -q "Tests bestanden\|Tests FEHLGESCHLAGEN" $G/run_tests.log 2>/dev/null; then
	rm -rf $S/xdg/rt; mkdir -p $S/xdg/rt; XDG_DATA_HOME=$S/xdg/rt nice -n 10 tools/run_tests.sh > $G/run_tests.log 2>&1
	echo "$(date +%T) run_tests exit $? – $(grep -E 'Tests, ' $G/run_tests.log | tail -1) – $(grep -cE '^CHECK .* OK' $G/run_tests.log) CHECK OK, $(grep -cE '^CHECK .* FEHLER' $G/run_tests.log) CHECK FEHLER" >> $G/summary.txt
fi
for t in head base; do
	for p in T1 T2 T3 T4 C1 S0 S4; do
		grep -qE "occl $t $p exit" $S/logs/occl_done.log 2>/dev/null && continue
		$S/sh/occl.sh $t $p >> $S/logs/occl_done.log 2>&1
	done
done
for st in golden modernkeep sight ergebnis perf; do
	grep -q "gate $st fertig" $G/summary.txt 2>/dev/null && continue
	$S/sh/gates.sh $st
done
echo "CHAIN2 DONE $(date +%T)" >> $G/summary.txt
