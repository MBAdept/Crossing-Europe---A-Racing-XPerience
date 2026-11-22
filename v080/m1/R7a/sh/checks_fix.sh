#!/bin/bash
# R7a: the headless race3d checks that run the streamer, after the warm-front change; then a short realistic perf run.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1
export TMPDIR=$S/tmp
mkdir -p "$S/xdg/chk" "$S/chk"
cd "$WT" || exit 2
for f in check_facade check_modern_stage check_seam check_terrain_plan check_attract_modern check_benchmark; do
	t0=$SECONDS
	XDG_DATA_HOME=$S/xdg/chk nice -n 10 timeout 1500 godot --headless --path . -s "res://tests/race3d/$f.gd" > "$S/chk/$f.log" 2>&1
	echo "$(date -u +%H:%M:%S) $f exit=$? $((SECONDS - t0)) s: $(grep -a -c 'CHECK .* OK' "$S/chk/$f.log") OK, $(grep -a -c -E 'CHECK .* FEHLER|SCRIPT ERROR' "$S/chk/$f.log") FEHLER"
done
MAXS=420 bash "$S/sh/stage.sh" kh_mine_ts4b mine modern medium kiel_hamburg kiel 12 normal 4
echo "$(date -u +%H:%M:%S) done"
