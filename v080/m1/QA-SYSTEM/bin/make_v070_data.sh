#!/bin/bash
# Builds a v0.7.0 user folder with the REAL v0.7.0 game (ref070): settings + leaderboards (script) and a savegame of
# a race in progress (run_race.gd --max-legs=1 through the real GameFlow).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
REF=$S/ref070
X=$S/xdg_v070
rm -rf "$X"; mkdir -p "$X"
cd "$REF" || exit 2
XDG_DATA_HOME=$X nice -n 10 timeout 600 godot --headless --path . -s res://tests/race/run_race.gd -- --race=kiel_nuernberg \
	--autopilot --no-countdown --max-legs=1 --timescale=40 > "$S/v070_race.log" 2>&1
echo "run_race exit=$?"
grep -E "^(LEG|ETAPPE|FEHLER|OK)|leg|Leg" "$S/v070_race.log" | head -10
XDG_DATA_HOME=$X nice -n 10 timeout 120 godot --headless --path . -s "$S/gd/v070_make_data.gd" > "$S/v070_data.log" 2>&1
echo "make_data exit=$?"
grep -E "SETTINGS|LB|ERROR" "$S/v070_data.log"
find "$X" -type f | sed "s|$X/||"
