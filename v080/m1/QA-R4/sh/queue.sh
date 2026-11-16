#!/bin/bash
# queue.sh <job> [<job> ...] – runs heavy jobs one after another (nice 10); a job with a marker in done/ is skipped.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-3
mkdir -p $S/done $S/logs
export XDG_DATA_HOME=$S/xdg_q
mkdir -p $XDG_DATA_HOME
for job in "$@"; do
	if [ -e "$S/done/$job" ]; then echo "skip $job"; continue; fi
	echo "=== $(date +%H:%M:%S) start $job"
	t0=$SECONDS
	case "$job" in
	scan) (cd $WT && nice -n 10 timeout 3000 godot --headless --path . -s $S/sh/scan_data.gd -- --windows=3) > $S/logs/scan.log 2>&1 ;;
	sight) (cd $WT && nice -n 10 timeout 3000 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full) > $S/logs/sight_full.log 2>&1 ;;
	path) (cd $WT && nice -n 10 timeout 3000 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full) > $S/logs/path_full.log 2>&1 ;;
	h_N1) $S/sh/ab.sh head N1_high N1 high --shot-times=2,4 > $S/logs/$job.log 2>&1 ;;
	h_N1deck) SCREEN=1280x800 $S/sh/ab.sh head N1_deck N1 deck --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	h_N2N) $S/sh/ab.sh head N2N_high N2N high --shot-times=2,4 > $S/logs/$job.log 2>&1 ;;
	h_N2Ndeck) SCREEN=1280x800 $S/sh/ab.sh head N2N_deck N2N deck --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	h_N2) $S/sh/ab.sh head N2_high N2 high --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	h_C1) $S/sh/ab.sh head C1_high C1 high --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	h_C1RN) $S/sh/ab.sh head C1RN_high C1RN high --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	h_DEV) $S/sh/ab.sh head DEV_high DEV high --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	h_DAWN) $S/sh/ab.sh head S1DAWN_high S1DAWN high --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	h_DUSK) $S/sh/ab.sh head S1DUSK_high S1DUSK high --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	h_OVC) $S/sh/ab.sh head S1OVC_high S1OVC high --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	h_OVCdeck) SCREEN=1280x800 $S/sh/ab.sh head S1OVC_deck S1OVC deck --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	h_TEXIT) $S/sh/ab.sh head TEXIT_high TEXIT high --shot-times=1.0,2.4,3.8 > $S/logs/$job.log 2>&1 ;;
	h_KBNS) $S/sh/ab.sh head KBNS_high KBNS high --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	b_N1) $S/sh/ab.sh base N1_high N1 high --shot-times=2,4 > $S/logs/$job.log 2>&1 ;;
	b_N2N) $S/sh/ab.sh base N2N_high N2N high --shot-times=2,4 > $S/logs/$job.log 2>&1 ;;
	b_N2) $S/sh/ab.sh base N2_high N2 high --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	b_C1) $S/sh/ab.sh base C1_high C1 high --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	b_DEV) $S/sh/ab.sh base DEV_high DEV high --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	b_DAWN) $S/sh/ab.sh base S1DAWN_high S1DAWN high --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	b_DUSK) $S/sh/ab.sh base S1DUSK_high S1DUSK high --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	b_OVC) $S/sh/ab.sh base S1OVC_high S1OVC high --shot-times=2 > $S/logs/$job.log 2>&1 ;;
	b_TEXIT) $S/sh/ab.sh base TEXIT_high TEXIT high --shot-times=1.0,2.4,3.8 > $S/logs/$job.log 2>&1 ;;
	x_streakoff) $S/sh/x_streakoff.sh > $S/logs/$job.log 2>&1 ;;
	rc_*)
		f=${job#rc_}
		(cd $WT && XDG_DATA_HOME=$S/xdg_rc MESA_SHADER_CACHE_DIR=$S/mesa_rc RENDER_CHECK_TIMEOUT=2400 tools/run_render_checks.sh modern "$f.gd") > $S/logs/$job.log 2>&1 ;;
	w_*)
		which=${job#w_}; tree=$WT; tag=head
		case "$which" in *_base) tree=$S/base; tag=base;; esac
		pos=${which%_head}; pos=${pos%_base}
		case "$pos" in
		N1) wargs="--stage=hamburg_hannover --from=hamburg --km=71 --hour=22 --weather=snow" ;;
		N2N) wargs="--stage=dortmund_frankfurt --from=dortmund --km=121 --hour=22 --weather=rain" ;;
		N2) wargs="--stage=dortmund_frankfurt --from=dortmund --km=121 --hour=16 --weather=rain" ;;
		esac
		rm -rf $S/warm/mesa_$which $S/warm/xdg_$which; mkdir -p $S/warm/mesa_$which $S/warm/xdg_$which
		(cd $tree && MESA_SHADER_CACHE_DIR=$S/warm/mesa_$which XDG_DATA_HOME=$S/warm/xdg_$which nice -n 10 timeout 2400 \
			xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x800 \
			-s res://tests/race3d/render/warmup_cold.gd -- --graphics=modern --gfx-preset=deck $wargs) > $S/logs/$job.log 2>&1
		rm -rf $S/warm/mesa_$which $S/warm/xdg_$which ;;
	*) echo "unknown job $job"; continue ;;
	esac
	rc=$?
	echo "=== $(date +%H:%M:%S) end $job rc=$rc ($((SECONDS - t0)) s)"
	echo "rc=$rc $((SECONDS - t0))s" > "$S/done/$job"
done
echo "=== QUEUE DONE $*"
