#!/bin/bash
# FIX-R7a queue 3: variant B with PUSH_MAX_M 12 in the scratch copy: realbuild, footprint, C1/München/Bern pictures, occl C1
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7a/sh/common.sh
sed -i 's/^const PUSH_MAX_M := 6.0 /const PUSH_MAX_M := 12.0/' $PFIX/scripts/race3d/builders/props.gd
grep -n "^const PUSH_MAX_M" $PFIX/scripts/race3d/builders/props.gd
(cd $PFIX && nice -n 10 timeout 900 godot --headless --path . -s res://tests/run_tests.gd -- --filter=test_props > $S/logs/pfixB12_test_props.log 2>&1); echo "B12 test_props exit=$?"
grep -E "Tests," $S/logs/pfixB12_test_props.log
$S/sh/realbuild_runs.sh "pushB12=$PFIX"
memwait
(cd $PFIX && nice -n 10 timeout 1800 godot --headless --path . -s res://tests/race3d/props_footprint.gd -- --full > $S/logs/footprint_full_pushB12.log 2>&1)
echo "footprint B12 exit=$?"; grep -E "^FOOTPRINT [0-9]+ directions|CHECK" $S/logs/footprint_full_pushB12.log
for n in C1 Muenchen Bern; do
	shot pushB $n high "" _b12
done
for f in $S/occl/C1_pushB_*.png $S/occl/C1_pushB.log; do [ -f "$f" ] && mv "$f" "${f/C1_pushB/C1_pushB6}"; done
occl pushB C1
mv $S/occl/C1_pushB.log $S/occl/C1_pushB12.log 2>/dev/null
for f in $S/occl/C1_pushB_*.png; do [ -f "$f" ] && mv "$f" "${f/C1_pushB_/C1_pushB12_}"; done
echo QUEUE3_DONE
