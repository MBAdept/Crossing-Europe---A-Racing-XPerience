#!/bin/bash
# Smoke test of the exports (RINT-B gate): the Windows build under wine64 and the Linux build each run one scene of
# the Leistungstest in the mode "Modern" (a real Modern stage: race scene, autopilot, renderer) and quit; the result
# file says whether Modern drew it (no "fallback") and how fast. wineserver -w between runs, TMPDIR unset.
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-B
OUT=$S/smoke
mkdir -p "$OUT"
unset TMPDIR
export LANG=C.UTF-8
printf 'pcm.!default { type null }\nctl.!default { type null }\n' > "$OUT/alsa_null.conf"
# Linux export
export XDG_DATA_HOME=$OUT/xdg_linux
mkdir -p "$XDG_DATA_HOME"
t0=$SECONDS
timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" "$WT/build/CrossingEurope.x86_64" --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 1280x720 -- --graphics=modern --no-chooser --bench=autobahn --bench-seconds=5 --bench-out="$OUT/linux_bench.json" \
	> "$OUT/linux.log" 2>&1
echo "linux exit=$? $((SECONDS - t0)) s"
# Windows export under Wine
export WINEPREFIX=$OUT/wineprefix
export WINEDLLOVERRIDES="mscoree,mshtml=;dinput8=d"
export ALSA_CONFIG_PATH=$OUT/alsa_null.conf
export WINEDEBUG=-all
if [ ! -d "$WINEPREFIX" ]; then
	timeout 600 xvfb-run -a wine64 wineboot -i > "$OUT/wineboot.log" 2>&1
	/usr/lib/wine/wineserver -w
fi
t0=$SECONDS
timeout 1200 xvfb-run -a -s "-screen 0 1280x720x24" wine64 "$WT/build/CrossingEurope.exe" --rendering-driver opengl3 \
	--resolution 1280x720 -- --graphics=modern --no-chooser --bench=autobahn --bench-seconds=5 \
	--bench-out="Z:$OUT/windows_bench.json" > "$OUT/windows.log" 2>&1
echo "windows exit=$? $((SECONDS - t0)) s"
/usr/lib/wine/wineserver -w
ls -la "$OUT"/*.json 2>/dev/null
