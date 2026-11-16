#!/bin/bash
# Master-bus captures of the loudness plan (gd/qa_capture_mix.gd = tools/audio/modern/capture_mix.gd with a Movie Maker
# clock and --race-music=0), default volumes (master 0.8): the drive with race music (ducking), the music alone under
# the same drive (car group muted), "Musik im Rennen: Aus", the menu music in both profiles. Then measure_mix.py.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
M=$S/mut
OUT=$S/mix
mkdir -p "$OUT"
cap() { # name args...
	local name=$1; shift
	local x=$S/xdg_mx_$name
	rm -rf "$x"; mkdir -p "$x"
	local t0=$SECONDS
	XDG_DATA_HOME=$x nice -n 10 timeout 2400 xvfb-run -a -s "-screen 0 640x360x24" godot --path "$M" --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 320x180 --write-movie "$x/movie.avi" --fixed-fps 60 -s "$S/gd/qa_capture_mix.gd" -- \
		--graphics=arcade --audio-sync --movie --out="$OUT/$name.wav" "$@" > "$OUT/$name.log" 2>&1
	echo "$name exit=$? $((SECONDS - t0)) s; Fehler/leaked: $(grep -cE 'SCRIPT ERROR|^ERROR|leaked|still in use' "$OUT/$name.log")"
	rm -rf "$x"
	python3 "$WT/tools/audio/modern/measure_mix.py" "$OUT/$name.wav" > "$OUT/$name.measure.txt" 2>&1
	sed 's/^/    /' "$OUT/$name.measure.txt" | head -20
}
CASES=${CASES:-"race_music race_music_only race_music_off menu_modern menu_arcade"}
for c in $CASES; do
	case $c in
	race_music)      cap mx_race_music --sound=modern --scenario=race_music --vehicle=gran_turismo ;;
	race_music_only) cap mx_race_music_only --sound=modern --scenario=race_music --vehicle=gran_turismo --mute-bus=MEnv ;;
	race_music_off)  cap mx_race_music_off --sound=modern --scenario=race_music --vehicle=gran_turismo --race-music=0 ;;
	menu_modern)     cap mx_menu_modern --sound=modern --scenario=menu --seconds=40 ;;
	menu_arcade)     cap mx_menu_arcade --sound=arcade --scenario=menu --seconds=40 ;;
	esac
done
echo ALLDONE
