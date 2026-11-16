#!/bin/bash
# NACH-M2 queue 3: gates on head 515dd51, after q2. Each step logs to logs/gate_<name>.log; idempotent per step
# (a step whose log ends with its END line is skipped).
N=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-M2
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-6
L=$N/logs/q3.log
while ! grep -q Q2-DONE $N/logs/q2.log 2>/dev/null; do sleep 20; done
export MESA_SHADER_CACHE_DIR=$N/mesa
export LP_NUM_THREADS=2
step() {  # step <name> <command…>
	local name=$1
	shift
	local G=$N/logs/gate_$name.log
	if grep -q "^STEP-END" "$G" 2>/dev/null; then echo "skip $name" >> $L; return; fi
	echo "$(date -u +%T) start $name" >> $L
	local t0=$SECONDS
	local X=$N/xdg/gate_$name
	rm -rf "$X"; mkdir -p "$X"
	(cd "$WT" && XDG_DATA_HOME=$X nice -n 10 "$@") > "$G" 2>&1
	local code=$?
	echo "STEP-END exit=$code $((SECONDS - t0)) s" >> "$G"
	echo "$(date -u +%T) end $name exit=$code $((SECONDS - t0)) s" >> $L
	rm -rf "$X"
}
step rc_vehicle tools/run_render_checks.sh modern vehicle_
step rc_light_base tools/run_render_checks.sh modern light_base
step rc_start tools/run_render_checks.sh modern start_km0
step rc_showroom tools/run_render_checks.sh modern showroom_render
step rc_budget env RENDER_CHECK_TIMEOUT=900 tools/run_render_checks.sh modern instance_budget
step run_tests tools/run_tests.sh
step golden env KEEP=$N/golden_keep tools/golden.sh check
echo "$(date -u +%T) Q3-DONE" >> $L
