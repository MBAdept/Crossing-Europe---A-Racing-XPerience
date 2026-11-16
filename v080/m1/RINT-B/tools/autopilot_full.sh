#!/bin/bash
# Complete Modern autopilot run of Kiel–Hamburg under Xvfb (RINT-B gate): tests/race/run_stage.gd with a real renderer,
# time scale 4 (physics stays at 1/60 s per tick), prints ERGEBNIS, PERF (the session's perf_stats, with the
# renderer's) and RUN; compared with the headless Arcade ERGEBNIS of tools/ergebnis.sh.
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-B
OUT=$S/autopilot
mkdir -p "$OUT"
export XDG_DATA_HOME=$OUT/xdg
mkdir -p "$XDG_DATA_HOME"
export MESA_SHADER_CACHE_DIR=$S/mesa_ab
cd "$WT" || exit 1
t0=$SECONDS
nice -n 10 timeout 7000 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	--resolution 1280x720 -s res://tests/race/run_stage.gd -- --graphics=modern --stage=kiel_hamburg --from=kiel \
	--timescale=4 --max-seconds=6500 > "$OUT/run.log" 2>&1
echo "exit=$? $((SECONDS - t0)) s"
grep -E "^(ERGEBNIS|PERF|RUN) |FEHLER|Too many instances|SCRIPT ERROR" "$OUT/run.log" | cut -c1-3000
