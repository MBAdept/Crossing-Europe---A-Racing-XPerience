#!/usr/bin/env bash
# FIX-WASSER (from FIX-ZS1's export_start.sh): pictures from the EXPORTED test build (Linux under Xvfb, Windows under
# wine64), Arcade and Modern, of
#   start  – the standing start of Kiel – Hamburg ("Mittel"), 1 s into the countdown and 1.5 s after "LOS!" (1 / 4.5 s)
#   bruecke – the Köhlbrandbrücke, flying start at km 78.6 ("Hoch"), 0.3 s and 1.5 s after the start
#   export_shots.sh linux|windows
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER
PLAT=$1
OUT=$S/smoke/export_$PLAT
rm -rf "$OUT"
mkdir -p "$OUT"
COMMON=(--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-traffic)
START=("${COMMON[@]}" --gfx-preset=medium --shot-times=1,4.5)
BRIDGE=("${COMMON[@]}" --gfx-preset=high --no-countdown --start-km=78.6 --start-speed=60 --shot-times=0.3,1.5)
if [ "$PLAT" = windows ]; then
	unset TMPDIR
	export LANG=C.UTF-8 WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=;dinput8=d"
	export WINEPREFIX=$S/smoke/win/wineprefix
	printf 'pcm.!default { type null }\nctl.!default { type null }\n' > "$OUT/alsa_null.conf"
	export ALSA_CONFIG_PATH="$OUT/alsa_null.conf"
	EXE=$S/testbuild/CrossingEurope-ZS1.exe
else
	EXE=$S/testbuild/CrossingEurope-ZS1.x86_64
	export XDG_DATA_HOME=$OUT/xdg
	export MESA_SHADER_CACHE_DIR=$S/mesa_export
	mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
fi
for scene in start bruecke; do
	if [ $scene = start ]; then ARGS=("${START[@]}"); else ARGS=("${BRIDGE[@]}"); fi
	for mode in arcade modern; do
		t0=$SECONDS
		if [ "$PLAT" = windows ]; then
			timeout 1200 xvfb-run -a -s "-screen 0 1280x720x24" wine64 "$EXE" --rendering-driver opengl3 --resolution 1280x720 -- \
				"${ARGS[@]}" --graphics=$mode --sound=$mode "--screenshot=Z:$OUT/${scene}_$mode" >"$OUT/${scene}_$mode.log" 2>&1
			code=$?
			wineserver -w
		else
			nice -n 5 timeout 1200 xvfb-run -a -s "-screen 0 1280x720x24" "$EXE" --rendering-driver opengl3 --audio-driver Dummy \
				--resolution 1280x720 -- "${ARGS[@]}" --graphics=$mode --sound=$mode "--screenshot=$OUT/${scene}_$mode" >"$OUT/${scene}_$mode.log" 2>&1
			code=$?
		fi
		echo "$PLAT $scene $mode exit $code ($((SECONDS - t0)) s)"
	done
	for nn in 00 01; do
		a=$OUT/${scene}_arcade_$nn.png
		m=$OUT/${scene}_modern_$nn.png
		if [ -s "$a" ] && [ -s "$m" ]; then
			convert \( "$a" -background '#10182c' -fill white -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Arcade ($PLAT-Export)" \) \
				\( "$m" -background '#10182c' -fill white -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Modern ($PLAT-Export)" \) \
				-background '#10182c' +smush 6 -quality 90 "$OUT/${scene}_ab_$nn.jpg" && echo "$OUT/${scene}_ab_$nn.jpg"
		else
			echo "Bild $scene $nn fehlt ($a / $m)"
		fi
	done
done
grep -hE "SCRIPT ERROR|Modus Modern nicht|^OpenGL API|Wächter|watchdog" "$OUT"/*.log | sort | uniq -c | head
