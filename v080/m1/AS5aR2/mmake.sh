#!/usr/bin/env bash
# AS5aR2: tools/golden.sh modern-make after looking at the two changed Modern goldens (s4_mittel, s5_niedrig)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2
source $S/env.sh
cd $WT
waitmem
echo "START $(date +%H:%M)"
nice -n 19 tools/golden.sh modern-make > $S/logs/gate/mmake.log 2>&1
echo "modern-make exit $? $(date +%H:%M): $(tail -4 $S/logs/gate/mmake.log | tr '\n' ' ')"
git status --short
