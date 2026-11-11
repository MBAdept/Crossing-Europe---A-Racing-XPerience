#!/usr/bin/env bash
# Smoke run of an exported build (v0.8.0, docs/dev/v080_contract.md §4.9.5, docs/qa-v080.md): starts Kiel – Hamburg
# through GameFlow (as "-- --stage=…" does for a player's build: exports cannot start a scene path, A-2) once in
# Arcade and once in Modern, takes two pictures of each, then drives one Leistungstest scene in Modern and reports
# where the build keeps its user data.
#
#   tools/smoke_modern.sh <executable> <out_dir>
#     <executable>  a Linux export (…x86_64): runs under Xvfb with software OpenGL
#                   a Windows export (….exe): runs under wine64 (own prefix, Xvfb) – Direct3D/ANGLE cannot be shown here
#
# Output in <out_dir>: <platform>_<mode>_00.png / _01.png (6 s and 14 s after the start of the stage), the logs,
# <platform>_bench.json (scene "autobahn", BENCH_S seconds) and smoke.txt (one line per step: OK | FEHLER + why).
# A step fails on an exit code other than 0, a missing picture, a script error, a fallback of Modern to Arcade or a
# Leistungstest file without a measured scene. Exit code 1 when a step failed.
#
# Environment: SMOKE_ARGS (more arguments of every run, e.g. --gfx-preset=high), BENCH_S (8), SMOKE_TIMEOUT (seconds
# per run, 1200), WINEPREFIX (default <out_dir>/wineprefix; created on first use, takes a minute), RES (1280x720).
# Every run uses the empty, absolute XDG_DATA_HOME <out_dir>/xdg (Linux) – never the player's own folder; under Wine
# the user folder lies inside the prefix (drive_c/users/<name>/AppData/Roaming).
set -uo pipefail
if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
	awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
	exit 2
fi
EXE=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
OUT=$2
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
RES=${RES:-1280x720}
BENCH_S=${BENCH_S:-8}
TIMEOUT=${SMOKE_TIMEOUT:-1200}
REPORT="$OUT/smoke.txt"
: > "$REPORT"
FAILED=0
case "$EXE" in
*.exe) PLATFORM=windows ;;
*) PLATFORM=linux ;;
esac
if [ ! -s "$EXE" ]; then
	echo "==> $EXE fehlt" >&2
	exit 2
fi
note() {
	echo "$*" | tee -a "$REPORT"
}

if [ "$PLATFORM" = windows ]; then
	unset TMPDIR   # Wine 9.0 with a long TMPDIR fails to start (A-1)
	export LANG=C.UTF-8 WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=;dinput8=d"
	export WINEPREFIX=${WINEPREFIX:-$OUT/wineprefix}
	printf 'pcm.!default { type null }\nctl.!default { type null }\n' > "$OUT/alsa_null.conf"
	export ALSA_CONFIG_PATH="$OUT/alsa_null.conf"
	WINESERVER=$(command -v wineserver || echo /usr/lib/wine/wineserver)
	if [ ! -d "$WINEPREFIX" ]; then
		t0=$SECONDS
		timeout 600 xvfb-run -a wine64 wineboot -i >"$OUT/wineboot.log" 2>&1
		"$WINESERVER" -w
		note "wineboot: $((SECONDS - t0)) s"
	fi
	PATHPRE="Z:"
else
	export XDG_DATA_HOME="$OUT/xdg"
	mkdir -p "$XDG_DATA_HOME"
	export MESA_SHADER_CACHE_DIR="${MESA_SHADER_CACHE_DIR:-$OUT/mesa}"
	mkdir -p "$MESA_SHADER_CACHE_DIR"
	PATHPRE=""
fi

# run <log> <arguments after -- …>: one start of the build
run() {
	local log=$1
	shift
	if [ "$PLATFORM" = windows ]; then
		# shellcheck disable=SC2086
		timeout "$TIMEOUT" xvfb-run -a -s "-screen 0 ${RES}x24" wine64 "$EXE" --rendering-driver opengl3 --resolution "$RES" \
			-- "$@" ${SMOKE_ARGS:-} >"$log" 2>&1
		local code=$?
		"$WINESERVER" -w
		return $code
	fi
	# shellcheck disable=SC2086
	nice -n 10 timeout "$TIMEOUT" xvfb-run -a -s "-screen 0 ${RES}x24" "$EXE" --rendering-driver opengl3 \
		--audio-driver Dummy --resolution "$RES" -- "$@" ${SMOKE_ARGS:-} >"$log" 2>&1
}

STAGE=(--stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --gfx-preset=medium)
for mode in arcade modern; do
	t0=$SECONDS
	log="$OUT/${PLATFORM}_$mode.log"
	rm -f "$OUT/${PLATFORM}_${mode}"_0[01].png
	run "$log" "${STAGE[@]}" --graphics=$mode --sound=$mode "--screenshot=$PATHPRE$OUT/${PLATFORM}_$mode" --shot-times=6,14
	code=$?
	why=""
	[ $code -eq 0 ] || why="Exit $code"
	for i in 00 01; do
		[ -s "$OUT/${PLATFORM}_${mode}_$i.png" ] || why="${why:+$why, }Bild $i fehlt"
	done
	grep -qE "SCRIPT ERROR|Parse Error|SHADER ERROR" "$log" && why="${why:+$why, }Skriptfehler"
	if [ $mode = modern ] && grep -q "Modus Modern nicht möglich" "$log"; then
		why="${why:+$why, }Rückfall auf Arcade ($(grep -m1 -o "Modus Modern nicht möglich ([^)]*)" "$log"))"
	fi
	api=$(grep -m1 '^OpenGL API' "$log" | sed 's/[[:space:]]*$//')
	if [ -z "$why" ]; then
		note "$PLATFORM $mode: OK ($((SECONDS - t0)) s; $api)"
	else
		note "$PLATFORM $mode: FEHLER – $why ($((SECONDS - t0)) s, siehe $log)"
		FAILED=1
	fi
done

t0=$SECONDS
log="$OUT/${PLATFORM}_bench.log"
rm -f "$OUT/${PLATFORM}_bench.json"
run "$log" --graphics=modern --no-chooser --bench=autobahn "--bench-seconds=$BENCH_S" "--bench-out=$PATHPRE$OUT/${PLATFORM}_bench.json"
code=$?
summary=$(python3 -I - "$OUT/${PLATFORM}_bench.json" <<'EOF'
import json, sys
try:
    r = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception as e:
    print("FEHLER keine lesbare Datei (%s)" % e)
    sys.exit(0)
sc = r.get("scenes") or []
if not sc:
    print("FEHLER keine gemessene Szene (fallback %r, error %r)" % (r.get("fallback"), r.get("error")))
    sys.exit(0)
s = sc[0]
print("OK %s: %.1f fps, p95 %.0f ms, Voreinstellung %s, Stufe %s, Version %s, Vorschlag %s/%s" % (
    s.get("id"), float(s.get("avg_fps", 0)), float(s.get("frame_ms_p95", 0)), r.get("preset"), r.get("tier"),
    r.get("game_version"), r.get("suggested_mode"), r.get("suggested_preset")))
EOF
)
case "$summary" in
OK*) [ $code -eq 0 ] && note "$PLATFORM Leistungstest: $summary ($((SECONDS - t0)) s)" || { note "$PLATFORM Leistungstest: FEHLER – Exit $code, $summary"; FAILED=1; } ;;
*)
	note "$PLATFORM Leistungstest: $summary (Exit $code, siehe $log)"
	FAILED=1
	;;
esac

# where the build keeps its user data (the test builds have their own folder)
if [ "$PLATFORM" = windows ]; then
	where=$(find "$WINEPREFIX/drive_c/users" -name leistungstest.json 2>/dev/null | head -1)
else
	where=$(find "$XDG_DATA_HOME" -name leistungstest.json 2>/dev/null | head -1)
fi
if [ -n "$where" ]; then
	note "$PLATFORM Nutzerordner: $(dirname "$where") ($(cd "$(dirname "$where")" && ls | tr '\n' ' '))"
else
	note "$PLATFORM Nutzerordner: leistungstest.json nicht gefunden – FEHLER"
	FAILED=1
fi
[ $FAILED -eq 0 ] && note "SMOKE $PLATFORM: OK" || note "SMOKE $PLATFORM: FEHLER"
exit $FAILED
