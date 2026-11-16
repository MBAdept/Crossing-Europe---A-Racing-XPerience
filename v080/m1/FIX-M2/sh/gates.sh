#!/bin/bash
# FIX-M2 final gates, one after the other (nice 10). Restartable: a step with "DONE <step>" in logs/gates.log is skipped.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-M2
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-5
L=$S/logs/gates.log
G=$S/gates
mkdir -p $G
cd $WT || exit 1
export XDG_DATA_HOME=$S/xdg/gates
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p $XDG_DATA_HOME
step() {   # step <name> <command...>
	local n=$1
	shift
	if grep -q "^DONE $n" $L 2>/dev/null; then echo "skip $n" >> $L; return; fi
	echo "$(date -u +%T) START $n" >> $L
	local t0=$SECONDS
	nice -n 10 "$@" > $G/$n.log 2>&1
	echo "DONE $n exit=$? $((SECONDS - t0)) s $(date -u +%T) load $(cut -d' ' -f1-3 /proc/loadavg)" >> $L
}
step import godot --headless --path . --import
step modern_make env KEEP=$G/modern_keep tools/golden.sh modern-make
step run_tests tools/run_tests.sh
step render_checks env RENDER_CHECK_TIMEOUT=1500 tools/run_render_checks.sh all
step golden_check tools/golden.sh check
echo "$(date -u +%T) GATES-END" >> $L
