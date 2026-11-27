#!/bin/bash
# W6: the whole test suite once more on the final state (after the test fixes, capped_turn, Atomium)
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
source $W6/env.sh
G=$W6/gates; L=$W6/logs/gates.log
cd $WT
t0=$(date +%s)
env XDG_DATA_HOME=$W6/xdg_tests nice -n 10 tools/run_tests.sh > $G/run_tests2.log 2>&1
echo "$(date +%T) GATE run_tests2 rc $? $(( $(date +%s) - t0 )) s head $(git rev-parse --short HEAD) $(grep -E '[0-9]+ Tests, [0-9]+ fehlgeschlagen' $G/run_tests2.log | tail -1)" >> $L
echo "$(date +%T) GATES6 DONE" >> $L
