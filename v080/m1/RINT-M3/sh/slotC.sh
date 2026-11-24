#!/bin/bash
# final head 720eaf4: modern-check (6/6 + GLES), check_scripts, builds, smoke – each step skipped when its summary line exists
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3
for st in moderncheck2 scripts2 builds smoke; do
	grep -q "gate $st fertig" $S/gates/summary.txt && continue
	$S/sh/gates.sh $st
done
echo "SLOTC DONE $(date +%T)"
