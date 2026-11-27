#!/bin/bash
# Deck preset A-30: whole test suite (headless checks incl. vehicles/shadows with preset deck), then the render checks
# that run a preset (vehicles, instance budgets), then the modern golden (presets of the slice are fixed, not deck)
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
source $W6/env.sh
G=$W6/gates_deck; L=$W6/logs/gates.log; mkdir -p $G
cd $WT
step() { local n=$1; shift; [ -f $G/$n.done ] && return; local t0=$(date +%s); "$@" > $G/$n.log 2>&1; local rc=$?
	echo "$(date +%T) GATE deck_$n rc $rc $(( $(date +%s) - t0 )) s" >> $L; echo $rc > $G/$n.done; }
echo "$(date +%T) GATES DECK start head $(git rev-parse --short HEAD) (+ Arbeitsstand)" >> $L
step run_tests env XDG_DATA_HOME=$W6/xdg_tests nice -n 10 tools/run_tests.sh
step render_budget nice -n 10 tools/run_render_checks.sh modern instance_budget
echo "$(date +%T) GATES DECK DONE" >> $L
