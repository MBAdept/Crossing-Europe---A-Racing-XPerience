#!/bin/bash
# QA1: the exported Linux test build started like a player does (no arguments) on a 1280x800 Xvfb display:
# chooser "GRAFIK WÄHLEN" -> Modern -> title -> Rennen starten -> race -> vehicle -> start time -> stage screen ->
# Start -> Modern stage loads and runs. Keyboard through xdotool, pictures with ImageMagick import.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA1
EXE=$S/testbuild/CrossingEurope-ZS1.x86_64
OUT=$S/smoke/walk
rm -rf "$OUT"
mkdir -p "$OUT"
X=$S/xdg_walk
rm -rf "$X"
mkdir -p "$X"
DISP=:93
Xvfb $DISP -screen 0 1280x800x24 -nolisten tcp > "$OUT/xvfb.log" 2>&1 &
XPID=$!
sleep 2
export DISPLAY=$DISP
export MESA_SHADER_CACHE_DIR=$S/mesa_walk
mkdir -p "$MESA_SHADER_CACHE_DIR"
XDG_DATA_HOME=$X nice -n 10 "$EXE" --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x800 > "$OUT/game.log" 2>&1 &
GPID=$!
shot() { import -window root "$OUT/$1.png" 2>/dev/null; echo "shot $1"; }
key() { xdotool mousemove 2 2; xdotool key --delay 150 "$@"; sleep 1; }
sleep 18; shot 01_auswahl
key Right; sleep 1; shot 02_auswahl_modern
key Return; sleep 5; shot 03_titel
key Return; sleep 4; shot 04_rennen_waehlen
key Return; sleep 4; shot 05_fahrzeug
key Return; sleep 4; shot 06_startzeit
key Return; sleep 5; shot 07_etappe
key Return; sleep 12; shot 08_laden
sleep 50; shot 09_rennen
sleep 30; shot 10_rennen_spaeter
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
