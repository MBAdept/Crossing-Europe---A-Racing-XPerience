#!/bin/bash
# Successor queue (after the container restart): one heavy job at a time, START/DONE lines in queue.log.
# Steps: wald tyre_wind followup modern_check quit2   (STEPS=... to choose; a step with a DONE line is skipped)
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
STEPS=${STEPS:-"wald tyre_wind followup modern_check quit2"}
for s in $STEPS; do
	case $s in
	wald)         step wald bash -c "cd $WT && XDG_DATA_HOME=$S/xdg_wald RENDER_CHECK_TIMEOUT=3000 tools/run_render_checks.sh modern instance_budget_wald" ;;
	tyre_wind)    step tyre_wind bash "$S/bin/tyre_wind.sh" ;;
	followup)     step followup bash "$S/bin/followup.sh" ;;
	modern_check) step modern_check bash -c "cd $WT && XDG_DATA_HOME=$S/xdg_mcheck KEEP=$S/mcheck_keep tools/golden.sh modern-check" ;;
	quit2)        step quit2 bash "$S/bin/quit_stage2.sh" ;;
	esac
done
echo "REST ALLDONE $STEPS $(date -u +%H:%M:%S)" >> "$Q"
