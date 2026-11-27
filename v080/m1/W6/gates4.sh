#!/bin/bash
# W6 gates after all exports (QUEUE R7 DONE): strictly one heavy job after the other (next to one A/B chain).
#   manifest-only, validate --report, sprite geometry (props), run_tests, render checks (modern), golden check (arcade),
#   golden modern-check with KEEP (pictures to look at). Resumable per step via marker files.
W6=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6
source $W6/env.sh
G=$W6/gates; L=$W6/logs/gates.log; mkdir -p $G $W6/xdg_tests $W6/tmp_golden
until grep -q "QUEUE R7 DONE" $W6/logs/queue_r7.log 2>/dev/null; do sleep 30; done
cd $WT
step() { # name command...
	local n=$1; shift
	[ -f $G/$n.done ] && return
	local t0=$(date +%s)
	"$@" > $G/$n.log 2>&1; local rc=$?
	echo "$(date +%T) GATE $n rc $rc $(( $(date +%s) - t0 )) s" >> $L
	echo $rc > $G/$n.done
}
echo "$(date +%T) GATES start head $(git rev-parse --short HEAD)" >> $L
step manifest nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --manifest-only
step status git status --porcelain
step validate nice -n 10 python3 tools/blender/validate_models.py --report
step spritegeo nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py --only props --jobs 1
step run_tests env XDG_DATA_HOME=$W6/xdg_tests nice -n 10 tools/run_tests.sh
step render nice -n 10 tools/run_render_checks.sh modern
step golden env TMPDIR=$W6/tmp_golden nice -n 10 tools/golden.sh check
step modern env TMPDIR=$W6/tmp_golden KEEP=$G/modern_keep nice -n 10 tools/golden.sh modern-check
echo "$(date +%T) GATES DONE" >> $L
