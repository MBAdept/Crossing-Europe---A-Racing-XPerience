#!/bin/bash
# 20 minutes of Modern driving through the real GameFlow (tests/race/run_race.gd: race selection, stages with the
# autopilot, results, route choices) under Xvfb, Modern picture + Modern sound (engine thread, race music), preset
# medium, time scale 1. Samples RSS, threads, open files and the log; afterwards: error lines, legs, memory curve.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
OUT=$S/soak
mkdir -p "$OUT"
X=$S/xdg_soak; rm -rf "$X"; mkdir -p "$X"
export MESA_SHADER_CACHE_DIR=$S/mesa_soak
SECS=${SECS:-1200}
RACE=${RACE:-kiel_nuernberg}
cd "$WT" || exit 2
t0=$SECONDS
XDG_DATA_HOME=$X nice -n 10 timeout $((SECS + 300)) xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy --resolution 1280x720 -s res://tests/race/run_race.gd -- --race=$RACE --autopilot \
	--graphics=modern --sound=modern --gfx-preset=medium --timescale=1 --max-seconds=$SECS > "$OUT/soak.log" 2>&1 &
PID=$!
: > "$OUT/rss.tsv"
while kill -0 $PID 2>/dev/null; do
	GP=$(pgrep -f "run_race.gd -- --race=$RACE" | grep -v xvfb | head -1)
	if [ -n "$GP" ]; then
		echo -e "$((SECONDS - t0))\t$(ps -o rss= -p "$GP" | tr -d ' ')\t$(ps -o nlwp= -p "$GP" | tr -d ' ')\t$(ls /proc/$GP/fd 2>/dev/null | wc -l)" >> "$OUT/rss.tsv"
	fi
	sleep 30
done
wait $PID
echo "soak exit=$? $((SECONDS - t0)) s"
grep -E "ETAPPE|RENNEN|FEHLER|RACE-RUN" "$OUT/soak.log" | cut -c1-240
echo "-- Fehler-/Warnzeilen (ohne V-Sync):"
grep -E "ERROR|SCRIPT ERROR|WARNING|leaked|still in use|Too many instances|underrun|Aussetzer" "$OUT/soak.log" | grep -v "V-Sync" | sort | uniq -c | sort -rn | head -15
echo "-- RSS (s, kB, threads, fds):"
awk 'NR==1 || NR%4==0' "$OUT/rss.tsv"
echo ALLDONE
