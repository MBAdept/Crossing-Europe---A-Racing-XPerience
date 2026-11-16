#!/usr/bin/env bash
# R5 gates on the final head (one at a time, nice 19 while QA_M2_FERTIG is missing). gates.sh [name…]
#   import scripts tests golden modern_check render sight path
R5=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R5
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-2
G=$R5/gates
mkdir -p $G $R5/tmp
cd $WT || exit 1
NICE=19
[ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ] && NICE=10
export TMPDIR=$R5/tmp
WANT=" $* "
want() { [ "$WANT" = "  " ] || [[ "$WANT" == *" $1 "* ]]; }
run() {   # run <name> <command…>: log to $G/<name>.log, prints the exit code and the time
	local name=$1
	shift
	local t0=$SECONDS
	echo "==> $name: $*" > $G/$name.log
	XDG_DATA_HOME=$G/xdg_$name nice -n $NICE "$@" >> $G/$name.log 2>&1
	local code=$?
	echo "==> exit $code, $((SECONDS - t0)) s" >> $G/$name.log
	echo "$name: exit $code, $((SECONDS - t0)) s"
	rm -rf $G/xdg_$name
}
mkdir -p $G/xdg_import $G/xdg_scripts $G/xdg_tests $G/xdg_golden $G/xdg_modern_check $G/xdg_render $G/xdg_sight $G/xdg_path
want import && run import godot --headless --path . --import
want scripts && run scripts timeout 600 godot --headless --path . -s res://tests/check_scripts.gd
want tests && run tests tools/run_tests.sh
want golden && run golden tools/golden.sh check
want modern_check && KEEP=$G/modern_keep run modern_check tools/golden.sh modern-check
want render && MESA_SHADER_CACHE_DIR=$R5/mesa run render tools/run_render_checks.sh all
want sight && run sight timeout 3600 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full
want path && run path timeout 3600 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full
echo GATES_DONE
