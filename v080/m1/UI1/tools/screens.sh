#!/usr/bin/env bash
# UI1: screenshots of every new screen at 1280x720 and 1280x800 into the deliver folder.
#   screens.sh [filter]
set -uo pipefail
BASE=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/UI1
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9693abb2-cee-2
OUT=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/UI1/screens
mkdir -p "$OUT"
APP="godot/app_userdata/Crossing Europe – A Racing Xperience"
# settings folders: arcade (no choice), modern (chosen)
for name in sc_arcade sc_modern; do
	mkdir -p "$BASE/xdg/$name/$APP"
done
echo '{"settings_version": 3, "player_name": "Anke"}' > "$BASE/xdg/sc_arcade/$APP/settings.json"
echo '{"settings_version": 3, "player_name": "Anke", "graphics_mode": "modern"}' > "$BASE/xdg/sc_modern/$APP/settings.json"
FILTER=${1:-}
shot() {   # id xdg args...
	local id=$1 xdg=$2; shift 2
	if [ -n "$FILTER" ] && [[ "$id" != *"$FILTER"* ]]; then return; fi
	for size in 1280x720 1280x800; do
		# keep the prepared settings: shot.sh mkdirs only
		SCREEN=$size TIMEOUT=120 "$BASE/tools/shot.sh" "$WT" "$OUT/${id}_${size#1280x}" "$xdg" "$@" --shot-times=1.6 >/dev/null 2>&1
		if [ -f "$OUT/${id}_${size#1280x}_00.png" ]; then
			mv "$OUT/${id}_${size#1280x}_00.png" "$OUT/${id}_${size#1280x}.png"
			echo "ok   ${id}_${size#1280x}.png"
		else
			echo "FEHLT ${id}_${size#1280x}"
		fi
	done
}
shot 01_optionen_allgemein sc_arcade --screen=options
shot 02_optionen_grafik_arcade sc_arcade --screen=options --options-tab=grafik
shot 03_optionen_grafik_modern sc_modern --screen=options --options-tab=grafik
shot 04_auswahl_modern_empfohlen sc_arcade --screen=graphics_choice --recommend=modern --existing-player=1
shot 05_auswahl_arcade_empfohlen sc_arcade --screen=graphics_choice --recommend=arcade --existing-player=0
shot 06_leistungstest_start sc_modern --screen=benchmark
shot 07_leistungstest_ergebnis sc_modern --screen=benchmark --bench-sample=ok
shot 08_leistungstest_langsam sc_modern --screen=benchmark --bench-sample=slow
shot 09_leistungstest_rueckfall sc_modern --screen=benchmark --bench-sample=fallback
shot 10_titel_absturzfrage sc_modern --screen=title --sample-crash-guard
shot 11_showroom_limousine sc_modern --screen=vehicle --sample-vehicle=limousine --showroom-force --showroom-still
shot 12_showroom_kompakt sc_modern --screen=vehicle --sample-vehicle=kompakt --showroom-force --showroom-still
shot 13_fahrzeugwahl_modern_sprite sc_modern --screen=vehicle --sample-vehicle=sportwagen
