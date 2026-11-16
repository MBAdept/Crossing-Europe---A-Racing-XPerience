#!/bin/bash
# Race music through the real GameFlow with the Modern sound (gd/qa_music_flow.gd, headless, live players): rotation of
# the race pieces over four stages, endings and stingers, interlude on the screens between stages, and once with
# "Musik im Rennen: Aus". Arcade picture (Rule 4), time scale 6.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
M=$S/mut
OUT=$S/music
mkdir -p "$OUT"
run() { # name args...
	local name=$1; shift
	local x=$S/xdg_mf_$name
	rm -rf "$x"; mkdir -p "$x"
	local t0=$SECONDS
	XDG_DATA_HOME=$x nice -n 10 timeout 2400 godot --headless --path "$M" -s "$S/gd/qa_music_flow.gd" -- --graphics=arcade \
		--sound=modern --race=kiel_nuernberg --autopilot --timescale=6 "$@" > "$OUT/$name.log" 2>&1
	echo "$name exit=$? $((SECONDS - t0)) s; Fehler/leaked: $(grep -cE 'SCRIPT ERROR|^ERROR|leaked|still in use' "$OUT/$name.log")"
	grep -E "SCRIPT ERROR|^ERROR|leaked|still in use|FEHLER" "$OUT/$name.log" | sort | uniq -c | head -5
	grep -E "ETAPPE|RENNEN|ENDE|PROFIL" "$OUT/$name.log" | head -12
	rm -rf "$x"
}
run mf_on --max-legs=4
run mf_off --max-legs=2 --race-music=0
echo ALLDONE
