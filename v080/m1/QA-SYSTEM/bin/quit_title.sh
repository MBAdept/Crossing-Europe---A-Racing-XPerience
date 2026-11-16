#!/bin/bash
# Graceful quit through the game's own path (title "Beenden" + confirmation, keyboard via xdotool) with the stored mode
# Modern (Modern sound and title remaster playing) and with Arcade; exit code, log lines, then a restart.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
OUT=$S/quit
mkdir -p "$OUT"
Xvfb :96 -screen 0 1280x720x24 -nolisten tcp > /dev/null 2>&1 &
XP=$!
sleep 2
export DISPLAY=:96
export MESA_SHADER_CACHE_DIR=$S/mesa_quit
UD() { echo "$1/godot/app_userdata/Crossing Europe – A Racing Xperience"; }
key() { xdotool mousemove 2 2; xdotool key --delay 150 "$@"; sleep 0.8; }
for mode in modern arcade; do
	X=$S/xdg_quit_title_$mode; rm -rf "$X"; mkdir -p "$(UD "$X")"
	printf '{"settings_version": 3, "graphics_mode": "%s", "fullscreen": false}\n' "$mode" > "$(UD "$X")/settings.json"
	for run in 1 2; do
		XDG_DATA_HOME=$X nice -n 10 godot --path "$WT" --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 \
			> "$OUT/qt_${mode}_$run.log" 2>&1 &
		P=$!
		sleep 20
		import -window root "$OUT/qt_${mode}_${run}_title.png" 2>/dev/null

		key Down Down Down Down Down Down
		key Return
		sleep 1
		import -window root "$OUT/qt_${mode}_${run}_confirm.png" 2>/dev/null
		key Right
		key Return
		t=0; while kill -0 $P 2>/dev/null && [ $t -lt 40 ]; do sleep 0.5; t=$((t + 1)); done
		if kill -0 $P 2>/dev/null; then echo "$mode $run: läuft noch nach $((t / 2)) s – kill"; import -window root "$OUT/qt_${mode}_${run}_stuck.png"; kill -9 $P; fi
		wait $P; code=$?
		echo "$mode $run: exit=$code nach $((t / 2)) s; Fehler/leaked: $(grep -cE 'ERROR|leaked|still in use|SCRIPT ERROR' "$OUT/qt_${mode}_$run.log")"
		grep -E "ERROR|leaked|still in use|SCRIPT ERROR|WARNING" "$OUT/qt_${mode}_$run.log" | grep -v V-Sync | head -5 | sed 's/^/    /'
	done
done
kill $XP
echo ALLDONE
