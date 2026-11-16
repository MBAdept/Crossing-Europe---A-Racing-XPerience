#!/usr/bin/env bash
# QA-WASSER: one run of the EXPORTED test build with screenshots.
#   xshot.sh <linux|windows> <out_prefix> <WxH> <arcade|modern> [game args after -- …]
# Fresh absolute XDG_DATA_HOME per run (Linux) / own WINEPREFIX (Windows), fixed 60 fps, --gfx-sync.
# Pictures: <out_prefix>_<mode>_NN.png, log <out_prefix>_<mode>.log
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-WASSER
PLAT=$1
OUT=$2
SCREEN=$3
MODE=$4
shift 4
mkdir -p "$(dirname "$OUT")"
rm -f "${OUT}_${MODE}"_[0-9][0-9].png
FAST=()
[ "$MODE" = arcade ] && FAST=(--shot-fast)
NAME=$(basename "$OUT")_$MODE
t0=$SECONDS
if [ "$PLAT" = windows ]; then
	unset TMPDIR
	export LANG=C.UTF-8 WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=;dinput8=d"
	export WINEPREFIX=$S/wine/prefix
	export XDG_DATA_HOME=$S/xdg/wine_$NAME
	rm -rf "$XDG_DATA_HOME" "$WINEPREFIX/drive_c/users/root/AppData/Roaming/crossing-europe-zwischenstand"
	mkdir -p "$S/wine" "$XDG_DATA_HOME"
	printf 'pcm.!default { type null }\nctl.!default { type null }\n' > "$S/wine/alsa_null.conf"
	export ALSA_CONFIG_PATH="$S/wine/alsa_null.conf"
	EXE=$S/win/CrossingEurope-ZS1.exe
	nice -n 5 timeout 2400 xvfb-run -a -s "-screen 0 ${SCREEN}x24" wine64 "$EXE" --rendering-driver opengl3 --resolution "$SCREEN" \
		--fixed-fps 60 -- "--screenshot=Z:${OUT}_${MODE}" "$@" "--graphics=$MODE" --gfx-sync "${FAST[@]}" >"${OUT}_${MODE}.log" 2>&1
	code=$?
	wineserver -w
else
	export XDG_DATA_HOME=$S/xdg/run_$NAME
	rm -rf "$XDG_DATA_HOME"
	mkdir -p "$XDG_DATA_HOME"
	export MESA_SHADER_CACHE_DIR=$S/mesa_export
	mkdir -p "$MESA_SHADER_CACHE_DIR"
	EXE=$S/lin/CrossingEurope-ZS1.x86_64
	nice -n 5 timeout 2400 xvfb-run -a -s "-screen 0 ${SCREEN}x24" "$EXE" --rendering-driver opengl3 --audio-driver Dummy \
		--resolution "$SCREEN" --fixed-fps 60 -- "--screenshot=${OUT}_${MODE}" "$@" "--graphics=$MODE" --gfx-sync "${FAST[@]}" \
		>"${OUT}_${MODE}.log" 2>&1
	code=$?
fi
n=$(find "$(dirname "$OUT")" -maxdepth 1 -name "$(basename "$OUT")_${MODE}_[0-9][0-9].png" | wc -l)
echo "$PLAT $(basename "$OUT") $MODE: exit $code, $n Bild(er), $((SECONDS - t0)) s"
grep -hE "SCRIPT ERROR|Parse Error|SHADER ERROR|Modus Modern nicht|Wächter|watchdog|^ERROR" "${OUT}_${MODE}.log" | sort | uniq -c | head -5
exit $code
