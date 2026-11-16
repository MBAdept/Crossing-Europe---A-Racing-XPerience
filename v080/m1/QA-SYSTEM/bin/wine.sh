#!/bin/bash
# Windows build under wine64 (Xvfb): starts a stage in Arcade and in Modern (GameFlow --stage, autopilot), pictures
# at 6 s and 14 s, plus a Leistungstest scene in Modern (writes its JSON). Own prefix in scratch, TMPDIR unset.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
OUT=$S/wine
mkdir -p "$OUT"
unset TMPDIR
export LANG=C.UTF-8
printf 'pcm.!default { type null }\nctl.!default { type null }\n' > "$OUT/alsa_null.conf"
export WINEPREFIX=$S/wineprefix
export WINEDLLOVERRIDES="mscoree,mshtml=;dinput8=d"
export ALSA_CONFIG_PATH=$OUT/alsa_null.conf
export WINEDEBUG=-all
EXE=$WT/build/CrossingEurope.exe
if [ ! -d "$WINEPREFIX" ]; then
	t0=$SECONDS
	timeout 600 xvfb-run -a wine64 wineboot -i > "$OUT/wineboot.log" 2>&1
	/usr/lib/wine/wineserver -w
	echo "wineboot $((SECONDS - t0)) s"
fi
for mode in arcade modern; do
	t0=$SECONDS
	timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" wine64 "$EXE" --rendering-driver opengl3 --resolution 1280x720 -- \
		--stage=kiel_hamburg --autopilot --graphics=$mode --sound=$mode --gfx-preset=medium \
		--screenshot="Z:$OUT/win_$mode" --shot-times=6,14 > "$OUT/win_$mode.log" 2>&1
	echo "windows $mode exit=$? $((SECONDS - t0)) s"
	/usr/lib/wine/wineserver -w
	grep -E "OpenGL API|ERROR|SCRIPT ERROR|Modus Modern nicht|leaked" "$OUT/win_$mode.log" | sort | uniq -c | head -8 | sed 's/^/    /'
done
t0=$SECONDS
timeout 1200 xvfb-run -a -s "-screen 0 1280x720x24" wine64 "$EXE" --rendering-driver opengl3 --resolution 1280x720 -- \
	--graphics=modern --no-chooser --bench=autobahn --bench-seconds=8 --bench-out="Z:$OUT/win_bench.json" > "$OUT/win_bench.log" 2>&1
echo "windows bench exit=$? $((SECONDS - t0)) s"
/usr/lib/wine/wineserver -w
ls -la "$OUT"
echo ALLDONE
