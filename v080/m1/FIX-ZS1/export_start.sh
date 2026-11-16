#!/usr/bin/env bash
# FIX-ZS1: pictures of the standing start of Kiel – Hamburg from the EXPORTED test build (Linux under Xvfb, Windows
# under wine64), Arcade and Modern ("Mittel"), 1 s into the countdown and 1.5 s after "LOS!" (shot times 1 and 4.5).
#   export_start.sh linux|windows
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-ZS1
PLAT=$1
OUT=$S/smoke/start_$PLAT
mkdir -p "$OUT"
STAGE=(--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-traffic --gfx-preset=medium --shot-times=1,4.5)
if [ "$PLAT" = windows ]; then
	unset TMPDIR
	export LANG=C.UTF-8 WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=;dinput8=d"
	export WINEPREFIX=$S/smoke/win/wineprefix
	printf 'pcm.!default { type null }\nctl.!default { type null }\n' > "$OUT/alsa_null.conf"
	export ALSA_CONFIG_PATH="$OUT/alsa_null.conf"
	EXE=$S/testbuild/CrossingEurope-ZS1.exe
	for mode in arcade modern; do
		t0=$SECONDS
		timeout 1200 xvfb-run -a -s "-screen 0 1280x720x24" wine64 "$EXE" --rendering-driver opengl3 --resolution 1280x720 -- \
			"${STAGE[@]}" --graphics=$mode --sound=$mode "--screenshot=Z:$OUT/${PLAT}_$mode" >"$OUT/${PLAT}_$mode.log" 2>&1
		echo "$PLAT $mode exit $? ($((SECONDS - t0)) s)"
		wineserver -w
	done
else
	EXE=$S/testbuild/CrossingEurope-ZS1.x86_64
	export XDG_DATA_HOME=$OUT/xdg
	export MESA_SHADER_CACHE_DIR=$S/mesa_export
	mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
	for mode in arcade modern; do
		t0=$SECONDS
		nice -n 5 timeout 1200 xvfb-run -a -s "-screen 0 1280x720x24" "$EXE" --rendering-driver opengl3 --audio-driver Dummy \
			--resolution 1280x720 -- "${STAGE[@]}" --graphics=$mode --sound=$mode "--screenshot=$OUT/${PLAT}_$mode" >"$OUT/${PLAT}_$mode.log" 2>&1
		echo "$PLAT $mode exit $? ($((SECONDS - t0)) s)"
	done
fi
for nn in 00 01; do
	a=$OUT/${PLAT}_arcade_$nn.png
	m=$OUT/${PLAT}_modern_$nn.png
	if [ -s "$a" ] && [ -s "$m" ]; then
		convert \( "$a" -background '#10182c' -fill white -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Arcade ($PLAT-Export)" \) \
			\( "$m" -background '#10182c' -fill white -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Modern ($PLAT-Export)" \) \
			-background '#10182c' +smush 6 -quality 90 "$OUT/${PLAT}_start_ab_$nn.jpg" && echo "$OUT/${PLAT}_start_ab_$nn.jpg"
	else
		echo "Bild $nn fehlt ($a / $m)"
	fi
done
grep -hE "SCRIPT ERROR|Modus Modern nicht|^OpenGL API" "$OUT"/${PLAT}_*.log | sort | uniq -c | head
