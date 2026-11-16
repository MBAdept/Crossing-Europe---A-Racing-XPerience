#!/bin/bash
# Captures of the Master bus (tools/audio/modern/capture_mix.gd, real time, headless): drive per car in both
# profiles, menu music, race music with and without the car (ducking). Sequential.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
OUT=$S/sound
mkdir -p "$OUT"
cd "$WT" || exit 2
cap() { # name args...
	local name=$1; shift
	local x=$S/xdg_sound
	rm -rf "$x"; mkdir -p "$x"
	local t0=$SECONDS
	XDG_DATA_HOME=$x nice -n 5 timeout 300 godot --headless --path . -s "$S/gd/qa_capture_mix.gd" -- \
		--graphics=arcade --out="$OUT/$name.wav" "$@" > "$OUT/$name.log" 2>&1
	echo "$name exit=$? $((SECONDS - t0)) s $(grep -c -E 'ERROR|WARNING' "$OUT/$name.log") err/warn lines"
}
CARS=${CARS:-"kompakt limousine kombi sportwagen gran_turismo"}
for car in $CARS; do
	cap "modern_drive_$car" --sound=modern --scenario=drive --vehicle=$car
done
if [ -z "${ONLY_MODERN:-}" ]; then
	for car in $CARS; do
		cap "arcade_drive_$car" --sound=arcade --scenario=drive --vehicle=$car
	done
	cap modern_menu --sound=modern --scenario=menu --seconds=40
	cap arcade_menu --sound=arcade --scenario=menu --seconds=40
	cap modern_race_music --sound=modern --scenario=race_music --vehicle=gran_turismo
	cap modern_race_music_only --sound=modern --scenario=race_music --vehicle=gran_turismo --mute-bus=MEnv
	cap modern_race_music_off --sound=modern --scenario=race_music --vehicle=gran_turismo --race-music=0
fi
echo ALLDONE
