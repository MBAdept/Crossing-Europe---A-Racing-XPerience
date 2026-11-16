#!/bin/bash
# QA-M2-BILD: cold-cache warm-up check (tests/race3d/render/warmup_cold.gd) – empty user folder and empty Mesa cache
# per run. M2: Kiel – Hamburg km 2, N1, N2 (medium); ZS1: Kiel – Hamburg km 2 (medium). Logs perf/warm_<name>.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
warm() {   # warm <tree> <name> <args...>
	local tree=$1 name=$2
	shift 2
	local wt=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-3
	[ "$tree" = zs1 ] && wt=$S/zs1tree
	if grep -q "RENDER-CHECK warmup_kalt" "$S/perf/warm_$name.log" 2> /dev/null; then echo "skip warm $name"; return; fi
	local x=$S/xdg/warm_$name m=$S/xdg/mesa_warm_$name
	rm -rf "$x" "$m"; mkdir -p "$x" "$m"
	local t0=$SECONDS
	(cd "$wt" && MESA_SHADER_CACHE_DIR=$m XDG_DATA_HOME=$x LP_NUM_THREADS=2 nice -n 10 timeout 1500 xvfb-run -a \
		-s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 \
		-s res://tests/race3d/render/warmup_cold.gd -- --graphics=modern --sound=arcade "$@" > "$S/perf/warm_$name.log" 2>&1)
	echo "$(date -u +%H:%M:%S) warm $tree $name exit=$? $((SECONDS - t0)) s"
	grep -E "RENDER-CHECK" "$S/perf/warm_$name.log" | cut -c1-400
	rm -rf "$x" "$m"
}
warm m2 m2_kh --stage=kiel_hamburg --from=kiel --km=2 --hour=12 --gfx-preset=medium
warm zs1 zs1_kh --stage=kiel_hamburg --from=kiel --km=2 --hour=12 --gfx-preset=medium
warm m2 m2_n1 --stage=hamburg_hannover --from=hamburg --km=71 --hour=22 --weather=snow --gfx-preset=medium
