#!/bin/bash
# queue11.sh – successor 3 after 7f0eae2 (warm-up layer): the checks that the change can touch, then the measurements.
# Resumable through queue9.log ("DONE <step>"), like queue9/10.
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1
L=$R4/queue9.log
nicev() {
	if [ -f /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ]; then
		echo 10
	else
		echo 19
	fi
}
run() {   # run <step> <command…>
	local s=$1
	shift
	grep -q "^DONE $s " "$L" 2>/dev/null && return 0
	echo "== $s start $(date -u +%T) head $(cd "$WT" && git rev-parse --short HEAD) load $(cut -d' ' -f1 /proc/loadavg) nice $(nicev)" >> "$L"
	NICE=$(nicev) "$@" >> "$L" 2>&1
	echo "DONE $s $(date -u +%T) exit=$?" >> "$L"
}
rc_facade() {
	cd "$WT" || return 2
	mkdir -p "$R4/data/rc11"
	XDG_DATA_HOME=$R4/data/rc11 MESA_SHADER_CACHE_DIR=$R4/mesa_gates nice -n "$(nicev)" timeout 1200 xvfb-run -a -s "-screen 0 1280x720x24" \
		godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 \
		-s res://tests/race3d/render/check_facade_render.gd -- --graphics=modern --gfx-sync --audio-sync > "$R4/gates/rc11_facade.log" 2>&1
	echo "exit=$?" >> "$R4/gates/rc11_facade.log"
	grep -a "RENDER-CHECK" "$R4/gates/rc11_facade.log" | cut -c1-200
}
mc_night() {
	cd "$WT" || return 2
	KEEP="$R4/gates/modern_keep11" nice -n "$(nicev)" tools/golden.sh modern-check modern_s1_nacht > "$R4/gates/modern_check11.log" 2>&1
	echo "exit=$?" >> "$R4/gates/modern_check11.log"
	grep -a "GOLDEN\|ANDERS\|identisch" "$R4/gates/modern_check11.log"
}
warm2() {
	mkdir -p "$R4/warm/v1"
	cp -f "$R4/warm/N1.log" "$R4/warm/v1/N1.log" 2>/dev/null
	cp -f "$R4/warm/N2.log" "$R4/warm/v1/N2.log" 2>/dev/null
	"$R4/sh/warm.sh"
}
for step in ${QUEUE11:-rc_facade mc_night warm2 bench_head bench_base stage_head stage_base clips}; do
	case "$step" in
	rc_facade) run rc_facade rc_facade ;;
	mc_night) run mc_night mc_night ;;
	warm2) run warm2 warm2 ;;
	bench_head) run bench_head "$R4/sh/bench.sh" head "$WT" medium deck low high ;;
	bench_base) run bench_base "$R4/sh/bench.sh" base "$R4/base" medium ;;
	stage_head) run stage_head "$R4/sh/stage.sh" head "$WT" ;;
	stage_base) run stage_base "$R4/sh/stage.sh" base "$R4/base" ;;
	clips) run clips "$R4/sh/clips.sh" N2N N1 TEXIT ;;
	esac
done
echo "QUEUE11_DONE $(date -u +%T)" >> "$L"
