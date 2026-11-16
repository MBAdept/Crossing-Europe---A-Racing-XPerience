#!/bin/bash
# Quit and restart in every screen of the game (real game on its own Xvfb display): each screen started with
# --screen=<name> (sample data) with the stored mode Modern (Modern sound), then quit the way a player does –
# WM_DELETE_WINDOW (window close button / Alt+F4) when the window takes it, else SIGTERM (Steam "Exit game") –,
# then a restart without any argument must show the title (no crash question, settings kept).
# Afterwards the Modern stage: quit while loading, driving, paused; SIGTERM while loading twice in a row (strikes).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
OUT=$S/quit
mkdir -p "$OUT"
DISP=""; for n in $(seq 71 89); do [ -e /tmp/.X11-unix/X$n ] || [ -e /tmp/.X$n-lock ] || { DISP=:$n; break; }; done
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
shot() { import -window root "$OUT/$1.png" 2>/dev/null; }
HOW=""
close_game() { # name ; WM_DELETE_WINDOW to every window of the process, else SIGTERM; waits for the exit
	local w t
	HOW=wm_delete
	for w in $(xdotool search --pid "$GPID" 2>/dev/null); do python3 "$S/bin/xclose.py" "$w" > /dev/null; done
	t=0
	while kill -0 "$GPID" 2>/dev/null && [ $t -lt 30 ]; do sleep 0.5; t=$((t + 1)); done
	if kill -0 "$GPID" 2>/dev/null; then
		HOW=sigterm
		kill -TERM "$GPID"
		t=0
		while kill -0 "$GPID" 2>/dev/null && [ $t -lt 30 ]; do sleep 0.5; t=$((t + 1)); done
	fi
	if kill -0 "$GPID" 2>/dev/null; then HOW=kill9; kill -9 "$GPID"; fi
	wait "$GPID" 2>/dev/null
	echo "  $1: beendet über $HOW, exit=$?"
}
report() { # name xdg log
	local ud; ud=$(UD "$2")
	local marker=nein
	[ -f "$ud/modern_start.lock" ] && marker=JA
	local errs
	errs=$(grep -cE "ERROR|SCRIPT ERROR|leaked|still in use|Parse Error" "$3")
	echo "  $1: Marker=$marker Fehlerzeilen=$errs settings=$(tr -d '\n\t ' < "$ud/settings.json" 2>/dev/null | cut -c1-160)"
	grep -E "ERROR|SCRIPT ERROR|leaked|still in use|WARNING" "$3" | grep -v "V-Sync" | sort | uniq -c | head -6 | sed 's/^/      /'
}
seed_settings() { # xdg
	mkdir -p "$(UD "$1")"
	printf '{"settings_version": 3, "graphics_mode": "modern", "fullscreen": false, "gfx_preset": "medium"}\n' > "$(UD "$1")/settings.json"
}

SCREENS=${SCREENS:-"title race_select vehicle start_time route_choice stage_screen result race_result stage_select leaderboards options ferry graphics_choice benchmark"}
for scr in $SCREENS; do
	X=$S/xdg_quit_$scr; rm -rf "$X"; seed_settings "$X"
	echo "S $scr"
	extra=()
	[ "$scr" = vehicle ] && extra=(--sample-vehicle=limousine)
	start_game "$X" "$OUT/s_$scr.log" -- --screen=$scr --graphics=modern --sound=modern "${extra[@]}"
	sleep 14; shot "s_${scr}"
	close_game "s_$scr"; report "s_$scr" "$X" "$OUT/s_$scr.log"
	start_game "$X" "$OUT/s_${scr}_restart.log"
	sleep 14; shot "s_${scr}_restart"
	close_game "s_${scr}_restart"; report "s_${scr}_restart" "$X" "$OUT/s_${scr}_restart.log"
done

# --- the Modern stage (GameFlow --stage): quit while loading / driving / paused
for case in loading driving paused; do
	X=$S/xdg_quit_stage_$case; rm -rf "$X"; seed_settings "$X"
	echo "R Modern-Etappe: $case"
	start_game "$X" "$OUT/r_$case.log" -- --stage=kiel_hamburg --graphics=modern --sound=modern --autopilot
	case $case in
	loading) sleep 5; shot r_loading ;;
	driving) sleep 45; shot r_driving ;;
	paused) sleep 45; xdotool key --delay 120 Escape; sleep 3; shot r_paused ;;
	esac
	close_game "r_$case"; report "r_$case" "$X" "$OUT/r_$case.log"
	start_game "$X" "$OUT/r_${case}_restart.log"
	sleep 14; shot "r_${case}_restart"
	close_game "r_${case}_restart"; report "r_${case}_restart" "$X" "$OUT/r_${case}_restart.log"
done

# --- SIGTERM while a Modern stage loads, twice in a row (FIX1 strikes: the first keeps Modern, the second stores Arcade)
X=$S/xdg_quit_strikes; rm -rf "$X"; seed_settings "$X"
for n in 1 2; do
	echo "T SIGTERM beim Laden #$n"
	start_game "$X" "$OUT/t_$n.log" -- --stage=kiel_hamburg --graphics=modern --sound=modern --autopilot
	sleep 5; kill -TERM "$GPID"; t=0; while kill -0 "$GPID" 2>/dev/null && [ $t -lt 30 ]; do sleep 0.5; t=$((t + 1)); done
	kill -0 "$GPID" 2>/dev/null && kill -9 "$GPID"; wait "$GPID"; echo "  t_$n: exit=$?"
	report "t_$n" "$X" "$OUT/t_$n.log"
	# restart without arguments: the crash question on the title; answer with the focused button (A / Return)
	start_game "$X" "$OUT/t_${n}_restart.log"
	sleep 14; shot "t_${n}_question"
	xdotool key --delay 150 Return; sleep 2; shot "t_${n}_answered"
	echo "  nach Antwort: $(tr -d '\n\t ' < "$(UD "$X")/settings.json" | cut -c1-160)  strikes=$(cat "$(UD "$X")/modern_start.strikes" 2>/dev/null)"
	close_game "t_${n}_restart"; report "t_${n}_restart" "$X" "$OUT/t_${n}_restart.log"
done
kill $XPID 2>/dev/null
echo ALLDONE
