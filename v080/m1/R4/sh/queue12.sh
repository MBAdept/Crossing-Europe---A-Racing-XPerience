#!/bin/bash
# queue12.sh – after queue11: Arcade golden check on the final head, cold-cache check N2 at night (22 Uhr, rain)
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1
L=$R4/queue9.log
until grep -q "QUEUE11_DONE" "$L"; do sleep 20; done
run() {
	local s=$1
	shift
	grep -q "^DONE $s " "$L" 2>/dev/null && return 0
	echo "== $s start $(date -u +%T) head $(cd "$WT" && git rev-parse --short HEAD) load $(cut -d' ' -f1 /proc/loadavg)" >> "$L"
	"$@" >> "$L" 2>&1
	echo "DONE $s $(date -u +%T) exit=$?" >> "$L"
}
gold() {
	cd "$WT" || return 2
	KEEP="$R4/gates/golden_keep12" nice -n 10 tools/golden.sh check > "$R4/gates/golden_check12.log" 2>&1
	echo "exit=$?" >> "$R4/gates/golden_check12.log"
	grep -a "GOLDEN" "$R4/gates/golden_check12.log"
}
warm_n2n() {
	cd "$WT" || return 2
	rm -rf "$R4/warm/mesa_N2N" "$R4/warm/xdg_N2N"
	mkdir -p "$R4/warm/mesa_N2N" "$R4/warm/xdg_N2N"
	MESA_SHADER_CACHE_DIR=$R4/warm/mesa_N2N XDG_DATA_HOME=$R4/warm/xdg_N2N nice -n 10 timeout 1500 \
		xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
		-s res://tests/race3d/render/warmup_cold.gd -- --graphics=modern --stage=dortmund_frankfurt --from=dortmund --km=121 \
		--hour=22 --weather=rain > "$R4/warm/N2N.log" 2>&1
	echo "exit=$?" >> "$R4/warm/N2N.log"
	grep -a "RENDER-CHECK" "$R4/warm/N2N.log" | cut -c1-300
	rm -rf "$R4/warm/xdg_N2N" "$R4/warm/mesa_N2N"
}
run warm_n2n warm_n2n
run golden_check2 gold
echo "QUEUE12_DONE $(date -u +%T)" >> "$L"
