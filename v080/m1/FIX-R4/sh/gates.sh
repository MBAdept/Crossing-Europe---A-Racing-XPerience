#!/bin/bash
# gates.sh [job…] – the gates of FIX-R4 one after the other (nice 10), logs in m1/FIX-R4/gates/<job>.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-5
G=$S/gates
mkdir -p $G
cd $WT || exit 2
for job in ${@:-golden modern sight path stage_head stage_base tests render}; do
	echo "== $job start $(date -u +%T)" >> $G/gates.log
	t0=$SECONDS
	case $job in
	golden) XDG_DATA_HOME=$S/xdg/golden nice -n 10 tools/golden.sh check > $G/golden.log 2>&1 ;;
	modern) KEEP=$G/modern_keep XDG_DATA_HOME=$S/xdg/golden nice -n 10 tools/golden.sh modern-check > $G/modern.log 2>&1 ;;
	sight) XDG_DATA_HOME=$S/xdg/sim nice -n 10 timeout 1800 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > $G/sight.log 2>&1 ;;
	path) XDG_DATA_HOME=$S/xdg/sim nice -n 10 timeout 1800 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > $G/path.log 2>&1 ;;
	stage_head) $S/sh/stage.sh head $WT > $G/stage_head.log 2>&1 ;;
	stage_base) $S/sh/stage.sh base $S/base > $G/stage_base.log 2>&1 ;;
	tests) XDG_DATA_HOME=$S/xdg/tests nice -n 10 tools/run_tests.sh > $G/tests.log 2>&1 ;;
	render) XDG_DATA_HOME=$S/xdg/render MESA_SHADER_CACHE_DIR=$S/mesa_render RENDER_CHECK_TIMEOUT=2700 nice -n 10 tools/run_render_checks.sh all > $G/render.log 2>&1 ;;
	esac
	echo "== $job exit=$? $((SECONDS - t0)) s $(date -u +%T)" >> $G/gates.log
done
echo GATES_DONE >> $G/gates.log
