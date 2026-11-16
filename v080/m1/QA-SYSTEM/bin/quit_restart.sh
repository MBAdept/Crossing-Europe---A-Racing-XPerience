#!/bin/bash
# Quit (window close = WM_DELETE_WINDOW, as the X button / Alt+F4 / a window manager) and restart in many screens,
# real game on its own Xvfb display, keyboard through xdotool. Checks exit code, log errors, crash-guard marker,
# settings and savegame after each case. Pictures into $OUT.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
OUT=$S/quit
mkdir -p "$OUT"
DISP=:97
RES=${RES:-1280x720}
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
win_id() { xdotool search --name "Crossing Europe" 2>/dev/null | head -1; }
shot() { import -window root "$OUT/$1.png" 2>/dev/null; }
close_game() { # name ; sends WM_DELETE_WINDOW and waits for the exit
	local w; w=$(win_id)
	if [ -z "$w" ]; then echo "  $1: kein Fenster"; return; fi
	python3 "$S/bin/xclose.py" "$w" > /dev/null
	local t=0
	while kill -0 "$GPID" 2>/dev/null && [ $t -lt 40 ]; do sleep 0.5; t=$((t + 1)); done
	if kill -0 "$GPID" 2>/dev/null; then echo "  $1: HÄNGT nach dem Schließen – kill"; kill -9 "$GPID"; fi
	wait "$GPID" 2>/dev/null
	echo "  $1: exit=$? nach $((t / 2)) s"
}
report() { # name xdg log
	local ud; ud=$(UD "$2")
	local marker=nein
	[ -f "$ud/modern_start.lock" ] && marker=JA
	local errs
	errs=$(grep -cE "ERROR|SCRIPT ERROR|leaked|still in use|Parse Error" "$3")
	echo "  $1: Marker=$marker Fehlerzeilen=$errs settings=$(tr -d '\n\t ' < "$ud/settings.json" 2>/dev/null | cut -c1-200)"
	grep -E "ERROR|SCRIPT ERROR|leaked|still in use|WARNING" "$3" | grep -v "V-Sync" | sort | uniq -c | head -6 | sed 's/^/      /'
}
key() { xdotool mousemove 2 2; xdotool key --delay 120 "$@"; sleep 0.6; }

# --- Q1 first start: chooser, close without a choice, restart (chooser again), choose Modern, close, restart (title)
X1=$S/xdg_quit1; rm -rf "$X1"; mkdir -p "$X1"
echo "Q1 Auswahl beim ersten Start"
start_game "$X1" "$OUT/q1a.log"; sleep 14; shot q1a_chooser; close_game q1a; report q1a "$X1" "$OUT/q1a.log"
start_game "$X1" "$OUT/q1b.log"; sleep 14; shot q1b_chooser_again
key Right; key Return; sleep 3; shot q1b_title_after_choice
close_game q1b; report q1b "$X1" "$OUT/q1b.log"
start_game "$X1" "$OUT/q1c.log"; sleep 14; shot q1c_restart_title; close_game q1c; report q1c "$X1" "$OUT/q1c.log"

# --- Q2 options: unsaved change, window closed in the options -> saved (Settings on WM_CLOSE_REQUEST)
echo "Q2 Optionen"
start_game "$X1" "$OUT/q2.log" -- --no-chooser; sleep 14
key Down Down Down; key Return; sleep 2; shot q2_options
key Next; sleep 1; key Left; sleep 1; shot q2_options_grafik_arcade
close_game q2; report q2 "$X1" "$OUT/q2.log"

# --- Q3 Modern stage: close during loading, while driving, while paused; SIGTERM during loading
for case in loading driving paused sigterm; do
	X3=$S/xdg_quit3_$case; rm -rf "$X3"; mkdir -p "$X3"
	# a player who chose Modern (stored), so the restart without arguments shows the title (or its crash question)
	mkdir -p "$(UD "$X3")"
	printf '{"settings_version": 3, "graphics_mode": "modern", "fullscreen": false}\n' > "$(UD "$X3")/settings.json"
	echo "Q3 Modern-Etappe: $case"
	start_game "$X3" "$OUT/q3_$case.log" -- --stage=kiel_hamburg --graphics=modern --sound=modern --gfx-preset=medium --autopilot
	case $case in
	loading) sleep 6; shot q3_loading; close_game q3_loading ;;
	driving) sleep 30; shot q3_driving; close_game q3_driving ;;
	paused) sleep 30; key Escape; sleep 2; shot q3_paused; close_game q3_paused ;;
	sigterm) sleep 6; kill -TERM "$GPID"; t=0; while kill -0 "$GPID" 2>/dev/null && [ $t -lt 30 ]; do sleep 0.5; t=$((t + 1)); done
		kill -0 "$GPID" 2>/dev/null && { echo "  sigterm: hängt – kill"; kill -9 "$GPID"; }
		wait "$GPID"; echo "  sigterm: exit=$?" ;;
	esac
	report "q3_$case" "$X3" "$OUT/q3_$case.log"
	# restart without any argument: chooser (nothing chosen) or – with a marker – the warning
	start_game "$X3" "$OUT/q3_${case}_restart.log"; sleep 14; shot "q3_${case}_restart"; close_game "q3_${case}_restart"
done

# --- Q4 window closed in screens with Modern content: vehicle choice (showroom code path), Leistungstest running
X4=$S/xdg_quit4; rm -rf "$X4"; mkdir -p "$(UD "$X4")"
printf '{"settings_version": 3, "graphics_mode": "modern", "fullscreen": false}\n' > "$(UD "$X4")/settings.json"
echo "Q4 Fahrzeugwahl (Modern, Showroom erzwungen)"
start_game "$X4" "$OUT/q4_vehicle.log" -- --screen=vehicle --sample-vehicle=limousine --showroom-force --graphics=modern
sleep 16; shot q4_vehicle_showroom; close_game q4_vehicle; report q4_vehicle "$X4" "$OUT/q4_vehicle.log"
echo "Q4 Leistungstest läuft"
start_game "$X4" "$OUT/q4_bench.log" -- --no-chooser --bench=all --graphics=modern
sleep 25; shot q4_bench_running; close_game q4_bench; report q4_bench "$X4" "$OUT/q4_bench.log"
ls "$(UD "$X4")" | sed 's/^/    /'

kill $XPID 2>/dev/null
echo ALLDONE
