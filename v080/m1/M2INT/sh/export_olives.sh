#!/usr/bin/env bash
# M2INT (lead note 7): the exported game (pck) loads the seed variants whose leaf atlas is their species' (variant_of):
# Barcelona – Montpellier km 42.7 (olives, cypresses, palms) in Modern from the Linux export (Xvfb) and the Windows
# export (wine64). usage: export_olives.sh <linux_exe> <windows_exe> <out_dir>
LIN=$1
WIN=$2
OUT=$3
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
ARGS=(--stage=barcelona_montpellier --from=barcelona --start-km=42.7 --hour=12 --weather=normal --vehicle=limousine
	--seed=5 --autopilot --autopilot-refuel=never --no-countdown --start-speed=100 --graphics=modern --sound=arcade
	--gfx-preset=high --shot-times=6)
export XDG_DATA_HOME=$OUT/xdg
mkdir -p "$XDG_DATA_HOME"
nice -n 10 timeout 1500 xvfb-run -a -s "-screen 0 1280x720x24" "$LIN" --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 1280x720 -- "${ARGS[@]}" "--screenshot=$OUT/linux_oliven" > "$OUT/linux.log" 2>&1
echo "linux exit $? – Bild $(ls "$OUT"/linux_oliven_00.png 2>/dev/null) – $(grep -cE 'SCRIPT ERROR|Modelldateien fehlen|nicht möglich|Failed loading|Cannot open' "$OUT/linux.log") Fehlerzeilen"
unset TMPDIR
export LANG=C.UTF-8 WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=;dinput8=d"
export WINEPREFIX=${WINEPREFIX:-$OUT/wineprefix}
printf 'pcm.!default { type null }\nctl.!default { type null }\n' > "$OUT/alsa_null.conf"
export ALSA_CONFIG_PATH="$OUT/alsa_null.conf"
WINESERVER=$(command -v wineserver || echo /usr/lib/wine/wineserver)
if [ ! -d "$WINEPREFIX" ]; then
	timeout 600 xvfb-run -a wine64 wineboot -i > "$OUT/wineboot.log" 2>&1
	"$WINESERVER" -w
fi
timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" wine64 "$WIN" --rendering-driver opengl3 --resolution 1280x720 -- \
	"${ARGS[@]}" "--screenshot=Z:$OUT/windows_oliven" > "$OUT/windows.log" 2>&1
code=$?
"$WINESERVER" -w
echo "windows exit $code – Bild $(ls "$OUT"/windows_oliven_00.png 2>/dev/null) – $(grep -cE 'SCRIPT ERROR|Modelldateien fehlen|nicht möglich|Failed loading|Cannot open' "$OUT/windows.log") Fehlerzeilen"
