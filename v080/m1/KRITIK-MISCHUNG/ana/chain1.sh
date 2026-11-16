#!/usr/bin/env bash
# KRITIK-MISCHUNG heavy chain 1 (sequential, nice 19): transitions, in-game interactive check, knob sketches.
set -u
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-MISCHUNG
cd "$K/ana" || exit 1
echo "== transitions $(date +%T)"
nice -n 19 python3 transitions.py "$K/copy" "$K/res/transitions.json" > "$K/logs/transitions.log" 2>&1
echo "   exit $? $(date +%T)"
echo "== check_music interactive $(date +%T)"
cd "$K/copy" && XDG_DATA_HOME="$K/xdg" nice -n 19 timeout 400 godot --headless --path . -s res://tests/unit/audio_modern/check_music.gd -- \
	--graphics=arcade --only=interactive > "$K/logs/check_music_interactive.log" 2>&1
echo "   exit $? $(date +%T)"
grep -E "^CHECK" "$K/logs/check_music_interactive.log"
cd "$K/ana" || exit 1
echo "== knobs $(date +%T)"
./knobs.sh "base:" "sub_m3:sub_db=-3" "sub_p3:sub_db=3" "bass_m3:bass_db=-3" "hs_m2_6k:high_shelf_db=-2" \
	"hs_m3_4k:high_shelf_db=-3,high_shelf_hz=4000"
nice -n 19 python3 knobs_ana.py "$K" > "$K/logs/knobs_ana.log" 2>&1
echo "== fertig $(date +%T)"
