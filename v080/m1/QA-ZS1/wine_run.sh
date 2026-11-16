#!/usr/bin/env bash
# QA-ZS1: the delivered Windows export under wine64 (own prefix, TMPDIR unset, Z: paths): Kiel - Hamburg from km 0
# in Modern (countdown 1 s, LOS + 1.5 s) and in Arcade, fixed 60 fps + --gfx-sync like the Linux A/B runs.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-ZS1
EXE=$S/win/CrossingEurope-ZS1.exe
OUT=$S/wine
mkdir -p "$OUT"
unset TMPDIR
export LANG=C.UTF-8 WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=;dinput8=d"
export WINEPREFIX=$OUT/prefix
printf 'pcm.!default { type null }\nctl.!default { type null }\n' > "$OUT/alsa_null.conf"
export ALSA_CONFIG_PATH="$OUT/alsa_null.conf"
WINESERVER=$(command -v wineserver || echo /usr/lib/wine/wineserver)
if [ ! -d "$WINEPREFIX" ]; then
	t0=$SECONDS
	timeout 600 xvfb-run -a wine64 wineboot -i > "$OUT/wineboot.log" 2>&1
	"$WINESERVER" -w
	echo "wineboot: $((SECONDS - t0)) s"
fi
STAGE=(--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --gfx-preset=medium --shot-times=1,4.5)
for mode in modern arcade; do
	rm -f "$OUT/win_${mode}"_0[0-9].png
	t0=$SECONDS
	nice -n 5 timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" wine64 "$EXE" --rendering-driver opengl3 --resolution 1280x720 --fixed-fps 60 -- \
		"${STAGE[@]}" --graphics=$mode --sound=$mode --gfx-sync --audio-sync "--screenshot=Z:$OUT/win_$mode" > "$OUT/win_$mode.log" 2>&1
	code=$?
	"$WINESERVER" -w
	echo "windows $mode: exit $code, $(ls "$OUT/win_${mode}"_0[0-9].png 2>/dev/null | wc -l) Bilder, $((SECONDS - t0)) s; $(grep -cE 'SCRIPT ERROR|Parse Error|SHADER ERROR' "$OUT/win_$mode.log") Skriptfehler; $(grep -m1 '^OpenGL API' "$OUT/win_$mode.log" | cut -c1-90); $(grep -o 'Modus Modern nicht möglich[^)]*)' "$OUT/win_$mode.log" | head -1)"
done
U=$(find "$WINEPREFIX/drive_c/users" -maxdepth 4 -type d -name crossing-europe-zwischenstand 2>/dev/null | head -1)
echo "Nutzerordner: $U ($(ls "$U" 2>/dev/null | tr '\n' ' '))"
echo WINEDONE
