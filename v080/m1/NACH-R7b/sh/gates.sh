#!/usr/bin/env bash
# NACH-R7b: gates on c50d58f, one heavy job at a time (logs in m1/NACH-R7b/gates/). Skips steps with a finished log.
#   STEPS="probe unit render held sight golden"
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7b
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-9
G=$S/gates
mkdir -p $G $S/tmp
export TMPDIR=$S/tmp
export MESA_SHADER_CACHE_DIR=$S/mesa
guard() { while [ "$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)" -lt 3000 ]; do sleep 20; done; }
fresh() { rm -rf "$1"; mkdir -p "$1"; }
cd $W
for step in ${STEPS:-unit render held sight golden}; do
	guard
	T0=$SECONDS
	case $step in
	probe)
		fresh $S/xdg_probe
		XDG_DATA_HOME=$S/xdg_probe nice -n 10 timeout 1800 tools/run_tests.sh test_zz_nach_r7b_probe > $G/probe.log 2>&1
		echo "probe rc=$? $((SECONDS - T0)) s"
		;;
	unit)
		for f in test_landmarks check_landmarks far_ground_water test_props; do
			fresh $S/xdg_unit
			XDG_DATA_HOME=$S/xdg_unit nice -n 10 timeout 1800 tools/run_tests.sh $f > $G/unit_$f.log 2>&1
			echo "unit $f rc=$? $((SECONDS - T0)) s"
		done
		;;
	render)
		fresh $S/xdg_render
		XDG_DATA_HOME=$S/xdg_render nice -n 10 tools/run_render_checks.sh modern landmarks_render > $G/render_landmarks.log 2>&1
		echo "render landmarks rc=$? $((SECONDS - T0)) s"
		;;
	held)
		for f in start_km0 terrain_cover light_base seam_render; do
			fresh $S/xdg_render
			XDG_DATA_HOME=$S/xdg_render nice -n 10 tools/run_render_checks.sh modern $f > $G/render_$f.log 2>&1
			echo "render $f rc=$? $((SECONDS - T0)) s"
		done
		;;
	sight)
		fresh $S/xdg_sight
		XDG_DATA_HOME=$S/xdg_sight nice -n 10 timeout 3600 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > $G/modern_sight_full.log 2>&1
		echo "sight rc=$? $((SECONDS - T0)) s"
		;;
	golden)
		fresh $S/xdg_golden
		XDG_DATA_HOME=$S/xdg_golden nice -n 10 tools/golden.sh check > $G/golden_check.log 2>&1
		echo "golden rc=$? $((SECONDS - T0)) s"
		;;
	modern)
		fresh $S/xdg_gm
		XDG_DATA_HOME=$S/xdg_gm nice -n 10 tools/golden.sh modern-check > $G/golden_modern.log 2>&1
		echo "golden modern rc=$? $((SECONDS - T0)) s"
		;;
	esac
done
echo "GATES FERTIG"
