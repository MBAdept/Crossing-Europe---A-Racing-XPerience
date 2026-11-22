#!/usr/bin/env bash
# QA-R7b: whole Modern stages head vs base at the Deck preset (1280x800), plus the landmark cost probe on the head.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7b
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-4
B=$S/base
G=$S/gates
mkdir -p $G
export MESA_SHADER_CACHE_DIR=$S/mesa
guard() { while [ "$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)" -lt 3000 ]; do sleep 20; done; }
for stage in ${STAGES:-kiel_hamburg:kiel bremen_dortmund:bremen}; do
	IFS=: read -r st from <<<"$stage"
	for tree in head base; do
		dir=$W
		[ $tree = base ] && dir=$B
		f=$G/perf_${tree}_${st}_deck_${HOUR:-12}.log
		[ -s $f ] && grep -q '^PERF' $f && continue
		guard
		X=$S/xdg_perf_$tree
		rm -rf $X
		mkdir -p $X
		(cd $dir && XDG_DATA_HOME=$X nice -n 10 timeout 1500 xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 \
			--audio-driver Dummy --resolution 1280x800 -s res://tests/race/run_stage.gd -- --stage=$st --from=$from --seed=7 \
			--timescale=40 --hour=${HOUR:-12} --graphics=modern --gfx-preset=deck > $f 2>&1)
		echo "$tree $st rc=$? $(grep -c 'SCRIPT ERROR' $f) script errors"
	done
done
if [ -z "${SKIP_COST:-}" ]; then
	for preset in deck high; do
		f=$G/lm_cost_$preset.log
		[ -s $f ] && grep -q COST_DONE $f && continue
		guard
		X=$S/xdg_perf_cost
		rm -rf $X
		mkdir -p $X
		scr=1280x720
		[ $preset = deck ] && scr=1280x800
		(cd $W && XDG_DATA_HOME=$X nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 ${scr}x24" godot --path . --rendering-driver opengl3 \
			--audio-driver Dummy --resolution $scr --fixed-fps 60 -s $S/sh/lm_cost.gd -- --graphics=modern --gfx-preset=$preset > $f 2>&1)
		echo "cost $preset rc=$?"
	done
fi
echo PERF_DONE
