#!/usr/bin/env bash
# FIX-R7b: a second perf sample (Kiel–Hamburg) and Bremen–Dortmund (procedural landmarks), head and base, then the
# Modern golden frame s4 kept from head and base to look at the difference.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7b
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-6
B=$S/base
G=$S/gates
export MESA_SHADER_CACHE_DIR=$S/mesa
guard() { while [ "$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)" -lt 3000 ]; do sleep 20; done; }
for run in kiel_hamburg:kiel:2 bremen_dortmund:bremen:1; do
	IFS=: read -r st from n <<<"$run"
	for tree in head base; do
		dir=$W
		[ $tree = base ] && dir=$B
		f=$G/perf${n}_${tree}_${st}_deck_12.log
		[ -s $f ] && grep -q '^PERF' $f && continue
		guard
		X=$S/xdg_perf2_$tree
		rm -rf $X; mkdir -p $X
		(cd $dir && XDG_DATA_HOME=$X nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 1280x800x24" godot --path . \
			--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x800 -s res://tests/race/run_stage.gd -- --stage=$st \
			--from=$from --seed=7 --timescale=40 --hour=12 --graphics=modern --gfx-preset=deck > $f 2>&1)
		echo "perf$n $tree $st rc=$? $(grep -c 'SCRIPT ERROR' $f) script errors"
	done
done
for tree in head base; do
	dir=$W
	[ $tree = base ] && dir=$B
	K=$S/keep_s4_$tree
	[ -s $K/modern_s4_mittel_00.png ] && continue
	guard
	X=$S/xdg_keep_$tree
	rm -rf $X $K; mkdir -p $X $K
	(cd $dir && XDG_DATA_HOME=$X KEEP=$K nice -n 10 tools/golden.sh modern-check s4 > $S/keep_s4_$tree.log 2>&1)
	echo "keep s4 $tree rc=$?"
done
echo EXTRA_DONE
