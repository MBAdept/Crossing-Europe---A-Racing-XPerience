#!/bin/bash
# Wind alone and tyres alone (Modern), Movie Maker clock, default volumes; measure_mix.py per phase.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
M=$S/mut
OUT=$S/tyrewind
mkdir -p "$OUT"
cap() { # name args...
	local name=$1; shift
	local x=$S/xdg_tw_$name
	rm -rf "$x"; mkdir -p "$x"
	local t0=$SECONDS
	XDG_DATA_HOME=$x nice -n 10 timeout 2400 xvfb-run -a -s "-screen 0 640x360x24" godot --path "$M" --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 320x180 --write-movie "$x/movie.avi" --fixed-fps 60 -s "$S/gd/qa_tyre_wind.gd" -- \
		--graphics=arcade --audio-sync --movie --race-music=0 --out="$OUT/$name.wav" "$@" > "$OUT/$name.log" 2>&1
	echo "$name exit=$? $((SECONDS - t0)) s; Fehler/leaked: $(grep -cE 'SCRIPT ERROR|^ERROR|leaked|still in use' "$OUT/$name.log")"
	rm -rf "$x"
	python3 "$WT/tools/audio/modern/measure_mix.py" "$OUT/$name.wav" > "$OUT/$name.measure.txt" 2>&1
	sed 's/^/    /' "$OUT/$name.measure.txt" | head -20
}
cap tw_wind --sound=modern --scenario=wind --vehicle=gran_turismo --mute-bus=MEngine,MEngineFx,MRoad,MMusic
cap tw_skid --sound=modern --scenario=skid --vehicle=gran_turismo --mute-bus=MEngine,MEngineFx,MWind,MMusic
cap tw_ui --sound=modern --scenario=ui --mute-bus=MMusic
echo ALLDONE
