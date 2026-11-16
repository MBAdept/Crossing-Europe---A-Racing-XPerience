#!/usr/bin/env bash
# engine-only capture_mix drive runs (MRoad and MWind muted) for the cars not measured yet; waits for cap_plan.sh
set -u
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_f5d01292-ef8-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-C1
OUT=$S/cap
while ! grep -q "== fertig" "$S/cap_plan.log" 2>/dev/null; do sleep 5; done
cd "$WT"
for car in ${CARS:-kombi limousine sportwagen}; do
	f="$OUT/${car}_engine.wav"
	echo "== $car engine"
	XDG_DATA_HOME="$S/xdg_cap" nice -n 19 timeout 300 godot --headless --path . -s res://tools/audio/modern/capture_mix.gd -- \
		--sound=modern --scenario=drive --vehicle="$car" --out="$f" --mute-bus=MRoad,MWind 2>&1 | grep -E "capture_mix|ERROR|SCRIPT" | head -5
done
echo "== fertig"
