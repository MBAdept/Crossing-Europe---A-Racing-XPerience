#!/bin/bash
# after gates_hud.sh: modern-check against the new modern_slice.md5 (written from the kept pictures)
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
source $W6/env.sh
G=$W6/gates_hud; L=$W6/logs/gates.log
until grep -q "GATES HUD DONE" $L; do sleep 30; done
cd $WT
step() { local n=$1; shift; [ -f $G/$n.done ] && return; local t0=$(date +%s); "$@" > $G/$n.log 2>&1; local rc=$?
	echo "$(date +%T) GATE hud_$n rc $rc $(( $(date +%s) - t0 )) s" >> $L; echo $rc > $G/$n.done; }
step modern2 env TMPDIR=$W6/tmp_golden GLES_ID= nice -n 10 tools/golden.sh modern-check
echo "$(date +%T) GATES HUD2 DONE" >> $L
