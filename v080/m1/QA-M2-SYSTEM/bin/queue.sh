#!/bin/bash
# The remaining heavy jobs of QA-M2-SYSTEM, strictly one after the other (never two at a time). Each step writes its
# own log; this file only lists start, end and exit code per step (queue.log). The Arcade golden check comes last.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
Q=$S/queue.log
step() { # name command...
	local name=$1; shift
	if grep -q "^DONE $name " "$Q" 2>/dev/null; then echo "SKIP $name (done before)" >> "$Q"; return; fi
	echo "START $name $(date -u +%H:%M:%S) load $(cut -d' ' -f1 /proc/loadavg)" >> "$Q"
	local t0=$SECONDS
	"$@" > "$S/q_$name.log" 2>&1
	echo "DONE $name exit=$? $((SECONDS - t0)) s $(date -u +%H:%M:%S)" >> "$Q"
}
STEPS=${STEPS:-"wait_render mutations sound2 mix music export_det fallback bench xclose quit soak builds smoke_linux smoke_wine golden"}
for s in $STEPS; do
	case $s in
	wait_render) step wait_render bash -c "until grep -q ALLDONE $S/render_rest.log; do sleep 15; done" ;;
	mutations)   step mutations env WHAT="base vehicles props terrain golden" bash "$S/bin/mutations.sh" ;;
	sound2)      step sound2 env CASES="concrete_nolim crash_music fuel_music" bash "$S/bin/race_sound2.sh" ;;
	mix)         step mix bash "$S/bin/mix_caps.sh" ;;
	music)       step music bash "$S/bin/music_flow.sh" ;;
	export_det)  step export_det bash "$S/bin/export_det.sh" ;;
	fallback)    step fallback bash "$S/bin/fallback.sh" ;;
	bench)       step bench bash "$S/bin/bench.sh" ;;
	xclose)      step xclose bash "$S/bin/xclose_test.sh" ;;
	quit)        step quit bash "$S/bin/quit_screens.sh" ;;
	soak)        step soak bash "$S/bin/soak.sh" ;;
	builds)      step builds bash "$S/bin/builds.sh" ;;
	smoke_linux) step smoke_linux bash -c "cd $WT && XDG_DATA_HOME=$S/xdg_build tools/smoke_modern.sh build/CrossingEurope.x86_64 $S/smoke_linux" ;;
	smoke_wine)  step smoke_wine bash -c "cd $WT && WINEPREFIX=$S/wineprefix XDG_DATA_HOME=$S/xdg_build tools/smoke_modern.sh build/CrossingEurope.exe $S/smoke_wine" ;;
	golden)      step golden bash -c "cd $WT && XDG_DATA_HOME=$S/xdg_golden KEEP=$S/golden_keep tools/golden.sh check" ;;
	esac
done
echo "QUEUE ALLDONE $(date -u +%H:%M:%S)" >> "$Q"
