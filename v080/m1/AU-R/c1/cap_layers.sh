#!/usr/bin/env bash
# layer previews (sequential, nice 19)
set -u
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_f5d01292-ef8-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-C1
cd "$WT"
run() {
	sc=$1; shift
	XDG_DATA_HOME="$S/xdg_cap" nice -n 19 timeout 400 godot --headless --path . -s "$S/layers_demo.gd" -- --scenario=$sc \
		--out="$S/cap/layer_$sc.wav" "$@" 2>&1 | grep -E "layers_demo|ERROR|SCRIPT" | cut -c1-160
}
run belaege --mute-bus=MEngine,MEngineFx,MWind
run ruettel --mute-bus=MEngine,MEngineFx,MWind
run wind --mute-bus=MEngine,MEngineFx,MRoad
run quietschen --mute-bus=MEngine,MEngineFx,MWind
run aufprall
echo "== fertig"
