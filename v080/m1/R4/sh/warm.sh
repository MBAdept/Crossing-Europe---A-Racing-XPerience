#!/bin/bash
# warm.sh – cold-cache warm-up check at N1 and N2 (empty Mesa cache and user folder each), logs in warm/<id>.log
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
WT=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1}
N=${NICE:-19}
mkdir -p "$R4/warm"
cd "$WT" || exit 2
run() {   # run <id> <args…>
	local id=$1
	shift
	rm -rf "$R4/warm/mesa_$id" "$R4/warm/xdg_$id"
	mkdir -p "$R4/warm/mesa_$id" "$R4/warm/xdg_$id"
	MESA_SHADER_CACHE_DIR=$R4/warm/mesa_$id XDG_DATA_HOME=$R4/warm/xdg_$id nice -n $N timeout 1500 \
		xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
		-s res://tests/race3d/render/warmup_cold.gd -- --graphics=modern "$@" > "$R4/warm/$id.log" 2>&1
	echo "exit=$?" >> "$R4/warm/$id.log"
	grep -a "RENDER-CHECK\|SCRIPT ERROR\|SHADER ERROR" "$R4/warm/$id.log" | head -5
	rm -rf "$R4/warm/xdg_$id"
}
run N1 --stage=hamburg_hannover --from=hamburg --km=71 --hour=22 --weather=snow
run N2 --stage=dortmund_frankfurt --from=dortmund --km=121 --hour=16 --weather=rain
echo WARM_DONE
