#!/bin/bash
# QA-ZS1: what the checklist asks the player to do in the menus, with the delivered Linux export (fresh user folder,
# 1280x720 Xvfb, keyboard through xdotool): chooser -> Modern -> title -> Optionen (page ALLGEMEIN: Klang, Musik im
# Rennen) -> Page Down (page GRAFIK: Grafik, Voreinstellung, Leistungstest) -> Leistungstest -> starten -> result page
# (path of leistungstest.json) -> where the file is.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-ZS1
EXE=$S/lin/CrossingEurope-ZS1.x86_64
OUT=$S/walk_opt
rm -rf "$OUT"
mkdir -p "$OUT"
X=$S/xdg_walk_opt
rm -rf "$X"
mkdir -p "$X"
DISP=:98
Xvfb $DISP -screen 0 1280x720x24 -nolisten tcp > "$OUT/xvfb.log" 2>&1 &
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
		echo "window: $WID $(xdotool getwindowgeometry $WID 2>/dev/null | tr '\n' ' ')"
	fi
	xdotool windowfocus --sync "$WID" 2>/dev/null
	xdotool mousemove --window "$WID" 6 712 2>/dev/null
}
key() { focus; xdotool key --delay 200 "$@"; sleep 1; }
sleep 20; shot 01_auswahl
key Right; key Return; sleep 6; shot 02_titel
key Down Down Down; sleep 1; shot 03_titel_optionen
key Return; sleep 4; shot 04_optionen_allgemein
key Next; sleep 3; shot 05_optionen_grafik
key Down Down Down Down Down Down Down Down; sleep 1; shot 06_grafik_leistungstest
key Return; sleep 4; shot 07_leistungstest_start
key Return; sleep 5; shot 08_leistungstest_laeuft
for i in $(seq 1 36); do
	sleep 10
	shot "09_lt_$(printf %02d "$i")"
	if [ -s "$X/crossing-europe-zwischenstand/leistungstest.json" ]; then
		sleep 6
		shot 10_ergebnis
		break
	fi
done
UD="$X/crossing-europe-zwischenstand"
ls -la "$UD" 2>&1
python3 -I -c "import json,sys; r=json.load(open(sys.argv[1])); print('preset', r.get('preset'), 'tier', r.get('tier'), 'version', r.get('game_version'), 'suggest', r.get('suggested_mode'), r.get('suggested_preset')); [print(' scene', s.get('id'), round(float(s.get('avg_fps',0)),1), 'fps', s.get('seconds', '')) for s in r.get('scenes', [])]" "$UD/leistungstest.json" 2>&1
kill -TERM $GPID 2>/dev/null
t=0
while kill -0 $GPID 2>/dev/null && [ $t -lt 30 ]; do sleep 0.5; t=$((t + 1)); done
kill -0 $GPID 2>/dev/null && kill -9 $GPID
wait $GPID 2>/dev/null
kill $XPID 2>/dev/null
grep -E "SCRIPT ERROR|^ERROR|Modus Modern nicht" "$OUT/game.log" | sort | uniq -c | head -10
echo OPTDONE
