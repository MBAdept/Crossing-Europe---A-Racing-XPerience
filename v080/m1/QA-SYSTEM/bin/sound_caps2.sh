#!/bin/bash
# Rest of the captures after the first queue was stopped: menu music in both profiles, race music with the car,
# music alone (car group muted, ducking follows the drive) and "Musik im Rennen: Aus".
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
OUT=$S/sound
mkdir -p "$OUT"
cd "$WT" || exit 2
cap() {
	local name=$1; shift
	local x=$S/xdg_sound
	rm -rf "$x"; mkdir -p "$x"
	local t0=$SECONDS
	XDG_DATA_HOME=$x nice -n 5 timeout 300 godot --headless --path . -s "$S/gd/qa_capture_mix.gd" -- \
		--graphics=arcade --out="$OUT/$name.wav" "$@" > "$OUT/$name.log" 2>&1
	echo "$name exit=$? $((SECONDS - t0)) s $(grep -c -E 'ERROR|WARNING' "$OUT/$name.log") err/warn lines"
}
cap modern_menu --sound=modern --scenario=menu --seconds=40
cap arcade_menu --sound=arcade --scenario=menu --seconds=40
cap modern_race_music --sound=modern --scenario=race_music --vehicle=gran_turismo
cap modern_race_music_only --sound=modern --scenario=race_music --vehicle=gran_turismo --mute-bus=MEnv
cap modern_race_music_off --sound=modern --scenario=race_music --vehicle=gran_turismo --race-music=0
echo ALLDONE
