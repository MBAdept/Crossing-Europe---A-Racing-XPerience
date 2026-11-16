#!/bin/bash
# QA-ZS1: the delivered Linux export started like a player (no arguments) on a 1280x800 Xvfb (Steam Deck size),
# fresh XDG_DATA_HOME: chooser "GRAFIK WÄHLEN" -> Modern -> title (version) -> race -> vehicle -> start time -> stage
# -> loading -> countdown (car must be there) -> pause. Keyboard through xdotool, pictures with ImageMagick import.
# Xvfb has no window manager: the game window (1280x720, centred) gets the keyboard focus with xdotool windowfocus.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-ZS1
EXE=$S/lin/CrossingEurope-ZS1.x86_64
OUT=$S/walk
rm -rf "$OUT"
mkdir -p "$OUT"
X=$S/xdg_walk
rm -rf "$X"
mkdir -p "$X"
DISP=:97
Xvfb $DISP -screen 0 1280x800x24 -nolisten tcp > "$OUT/xvfb.log" 2>&1 &
XPID=$!
sleep 2
export DISPLAY=$DISP
export MESA_SHADER_CACHE_DIR=$S/mesa_walk
mkdir -p "$MESA_SHADER_CACHE_DIR"
T0=$SECONDS
XDG_DATA_HOME=$X nice -n 5 "$EXE" --rendering-driver opengl3 --audio-driver Dummy > "$OUT/game.log" 2>&1 &
GPID=$!
shot() { import -window root "$OUT/$1.png" 2>/dev/null; echo "shot $1 t=$((SECONDS - T0)) s"; }
WID=""
focus() {
	if [ -z "$WID" ]; then
		WID=$(xdotool search --pid $GPID 2>/dev/null | tail -1)
		[ -z "$WID" ] && WID=$(xdotool search --name "Crossing" 2>/dev/null | tail -1)
		echo "window: $WID $(xdotool getwindowgeometry $WID 2>/dev/null | tr '\n' ' ')"
	fi
	xdotool windowfocus --sync "$WID" 2>/dev/null
	# the pointer inside the window, bottom left (the key hints, nothing to hover)
	xdotool mousemove --window "$WID" 6 712 2>/dev/null
}
key() { focus; xdotool key --delay 150 "$@"; sleep 1; }
sleep 20; shot 01_auswahl
key Right; sleep 1; shot 02_auswahl_rechts
key Return; sleep 6; shot 03_titel
key Return; sleep 4; shot 04_nach_enter1
key Return; sleep 4; shot 05_nach_enter2
key Return; sleep 4; shot 06_nach_enter3
key Return; sleep 4; shot 07_nach_enter4
key Return; sleep 6; shot 08_nach_enter5
for i in $(seq 1 40); do
	sleep 2
	shot "09_rennen_$(printf %02d "$i")"
done
key Escape; sleep 3; shot 11_pause
UD="$X/crossing-europe-zwischenstand"
echo "user dir: $UD"
ls -la "$UD" 2>&1
echo "settings: $(tr -d '\n\t ' < "$UD/settings.json" 2>/dev/null | cut -c1-600)"
kill -TERM $GPID 2>/dev/null
t=0
while kill -0 $GPID 2>/dev/null && [ $t -lt 30 ]; do sleep 0.5; t=$((t + 1)); done
kill -0 $GPID 2>/dev/null && kill -9 $GPID
wait $GPID 2>/dev/null
echo "game exit=$?"
kill $XPID 2>/dev/null
grep -E "OpenGL API|SCRIPT ERROR|^ERROR|Modus Modern nicht|leaked|WARNING" "$OUT/game.log" | sort | uniq -c | head -20
ls -la "$X"
echo ALLDONE
