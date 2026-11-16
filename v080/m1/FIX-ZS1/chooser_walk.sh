#!/bin/bash
# FIX-ZS1 (from QA1's chooser_walk.sh): the exported Linux test build started like a player does (no arguments) on a
# 1280x800 Xvfb display: chooser "GRAFIK WÄHLEN" -> Modern -> title -> Rennen starten -> race -> vehicle -> start time
# -> stage screen -> Start -> Modern stage loads; pictures in the countdown (the car must be there) and later.
# Keyboard through xdotool, pictures with ImageMagick import.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-ZS1
EXE=$S/testbuild/CrossingEurope-ZS1.x86_64
OUT=$S/smoke/walk
rm -rf "$OUT"
mkdir -p "$OUT"
X=$S/xdg_walk
rm -rf "$X"
mkdir -p "$X"
DISP=:94
Xvfb $DISP -screen 0 1280x800x24 -nolisten tcp > "$OUT/xvfb.log" 2>&1 &
XPID=$!
sleep 2
export DISPLAY=$DISP
export MESA_SHADER_CACHE_DIR=$S/mesa_walk
mkdir -p "$MESA_SHADER_CACHE_DIR"
XDG_DATA_HOME=$X nice -n 5 "$EXE" --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x800 > "$OUT/game.log" 2>&1 &
GPID=$!
shot() { import -window root "$OUT/$1.png" 2>/dev/null; echo "shot $1 $(date -u +%T)"; }
key() { xdotool mousemove 2 2; xdotool key --delay 150 "$@"; sleep 1; }
sleep 18; shot 01_auswahl
key Right; sleep 1; shot 02_auswahl_modern
key Return; sleep 5; shot 03_titel
key Return; sleep 4; shot 04_rennen_waehlen
key Return; sleep 4; shot 05_fahrzeug
key Return; sleep 4; shot 06_startzeit
key Return; sleep 5; shot 07_etappe
key Return; sleep 6; shot 08_laden
# the loading picture, then the countdown: pictures every few seconds so that one lies in the countdown
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
	sleep 3
	shot "09_rennen_$(printf %02d "$i")"
done
key Escape; sleep 3; shot 11_pause
UD="$X/crossing-europe-zwischenstand"
echo "user dir: $UD"
ls -la "$UD" 2>&1
echo "settings: $(tr -d '\n\t ' < "$UD/settings.json" 2>/dev/null | cut -c1-400)"
kill -TERM $GPID 2>/dev/null
t=0
while kill -0 $GPID 2>/dev/null && [ $t -lt 30 ]; do sleep 0.5; t=$((t + 1)); done
kill -0 $GPID 2>/dev/null && kill -9 $GPID
wait $GPID 2>/dev/null
echo "game exit=$?"
kill $XPID 2>/dev/null
grep -E "OpenGL API|SCRIPT ERROR|^ERROR|Modus Modern nicht|leaked" "$OUT/game.log" | sort | uniq -c | head -10
ls "$X"
echo ALLDONE
