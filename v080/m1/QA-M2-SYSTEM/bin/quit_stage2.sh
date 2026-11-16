#!/bin/bash
# Second run of the Modern-stage quit cases with state-based timing. In quit_screens.sh the fixed waits (45 s) were
# too short under load 26: the stage was still loading in "driving" and "paused", and SIGTERM #2 of the strike case
# came before the marker was armed. Here:
#   driving  = wait until the race session armed the crash marker AND removed it again (2 s of drawn Modern frames),
#              then 8 s more, picture, SIGTERM; restart: title WITHOUT the crash question, settings Modern.
#   paused   = the same, then Escape (pause menu), picture, SIGTERM; restart as above.
#   strike2  = in xdg_quit_strikes (strike count 1 from #1): start the stage, wait until the marker is armed, SIGTERM;
#              restart: the question with the "zum zweiten Mal" text; Return (focused "Bei Arcade bleiben") must store
#              Arcade, remove marker and strike file.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
OUT=$S/quit2
mkdir -p "$OUT"
DISP=""; for n in $(seq 71 89); do [ -e /tmp/.X11-unix/X$n ] || [ -e /tmp/.X$n-lock ] || { DISP=:$n; break; }; done
RES=1280x720
Xvfb $DISP -screen 0 ${RES}x24 -nolisten tcp > "$OUT/xvfb.log" 2>&1 &
XPID=$!
sleep 2
export DISPLAY=$DISP
export MESA_SHADER_CACHE_DIR=$S/mesa_quit
UD() { echo "$1/godot/app_userdata/Crossing Europe – A Racing Xperience"; }
GPID=""
start_game() { # xdg log args...
	local xdg=$1 log=$2; shift 2
	XDG_DATA_HOME=$xdg nice -n 10 godot --path "$WT" --rendering-driver opengl3 --audio-driver Dummy --resolution "$RES" "$@" > "$log" 2>&1 &
	GPID=$!
}
shot() { import -window root "$OUT/$1.png" 2>/dev/null; }
term_game() { # name
	kill -TERM "$GPID" 2>/dev/null
	local t=0
	while kill -0 "$GPID" 2>/dev/null && [ $t -lt 60 ]; do sleep 0.5; t=$((t + 1)); done
	kill -0 "$GPID" 2>/dev/null && { echo "  $1: SIGTERM nach 30 s nicht beendet -> kill -9"; kill -9 "$GPID"; }
	wait "$GPID" 2>/dev/null
	echo "  $1: exit=$?"
}
state() { # xdg
	local ud; ud=$(UD "$1")
	echo "Marker=$([ -f "$ud/modern_start.lock" ] && echo JA || echo nein) Strikes=$(cat "$ud/modern_start.strikes" 2>/dev/null || echo -) settings=$(tr -d '\n\t ' < "$ud/settings.json" 2>/dev/null | cut -c1-120)"
}
errs() { grep -E "ERROR|SCRIPT ERROR|leaked|still in use|Parse Error" "$1" | sort | uniq -c | head -5 | sed 's/^/      /'; }
wait_marker() { # xdg seconds -> 0 when the marker exists
	local ud t=0; ud=$(UD "$1")
	while [ ! -f "$ud/modern_start.lock" ] && [ $t -lt "$2" ] && kill -0 "$GPID" 2>/dev/null; do sleep 1; t=$((t + 1)); done
	[ -f "$ud/modern_start.lock" ] && echo "    Marker gesetzt nach ${t} s" && return 0
	echo "    Marker nach ${t} s nicht gesetzt"; return 1
}
wait_disarm() { # xdg seconds -> 0 when the marker is gone again
	local ud t=0; ud=$(UD "$1")
	while [ -f "$ud/modern_start.lock" ] && [ $t -lt "$2" ] && kill -0 "$GPID" 2>/dev/null; do sleep 1; t=$((t + 1)); done
	[ ! -f "$ud/modern_start.lock" ] && echo "    Marker entfernt (Modern zeichnet) nach weiteren ${t} s" && return 0
	echo "    Marker nach ${t} s noch da"; return 1
}
seed_settings() {
	mkdir -p "$(UD "$1")"
	printf '{"settings_version": 3, "graphics_mode": "modern", "fullscreen": false, "gfx_preset": "medium"}\n' > "$(UD "$1")/settings.json"
}

for case in driving paused; do
	X=$S/xdg_quit2_$case; rm -rf "$X"; seed_settings "$X"
	echo "R Modern-Etappe: $case"
	t0=$SECONDS
	start_game "$X" "$OUT/r_$case.log" -- --stage=kiel_hamburg --graphics=modern --sound=modern --autopilot
	wait_marker "$X" 400 && wait_disarm "$X" 900
	sleep 8
	if [ $case = paused ]; then xdotool key --delay 120 Escape; sleep 4; fi
	shot "r_$case"
	echo "    vor SIGTERM ($((SECONDS - t0)) s): $(state "$X")"
	term_game "r_$case"
	echo "    nach SIGTERM: $(state "$X")"; errs "$OUT/r_$case.log"
	start_game "$X" "$OUT/r_${case}_restart.log"
	sleep 25; shot "r_${case}_restart"
	echo "    Neustart: $(state "$X")"
	term_game "r_${case}_restart"; errs "$OUT/r_${case}_restart.log"
done

X=$S/xdg_quit_strikes
echo "T SIGTERM beim Laden #2 (Zustand vorher: $(state "$X"))"
start_game "$X" "$OUT/t_2.log" -- --stage=kiel_hamburg --graphics=modern --sound=modern --autopilot
wait_marker "$X" 400
sleep 1
term_game t_2
echo "    nach SIGTERM: $(state "$X")"
start_game "$X" "$OUT/t_2_restart.log"
sleep 25; shot t_2_question
xdotool key --delay 150 Return; sleep 3; shot t_2_answered
echo "    nach Antwort (Return = fokussiert „Bei Arcade bleiben“): $(state "$X")"
term_game t_2_restart; errs "$OUT/t_2_restart.log"
# and the next start: Arcade without a question
start_game "$X" "$OUT/t_2_next.log"
sleep 25; shot t_2_next
echo "    nächster Start: $(state "$X")"
term_game t_2_next
kill $XPID 2>/dev/null
echo ALLDONE
