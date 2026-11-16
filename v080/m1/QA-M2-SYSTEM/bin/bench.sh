#!/bin/bash
# Leistungstest from the command line (--bench=all) under Xvfb with the default quality of this machine, then the
# format check of both result files (user://leistungstest.json and --bench-out). Plus the Leistungstest with
# --gfx-debug=fail (must write a file with the fallback and quit).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
OUT=$S/bench
mkdir -p "$OUT"
X=$S/xdg_bench; rm -rf "$X"; mkdir -p "$X"
export MESA_SHADER_CACHE_DIR=$S/mesa_bench
cd "$WT" || exit 2
t0=$SECONDS
XDG_DATA_HOME=$X nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy --resolution 1280x720 -- --graphics=modern --no-chooser --bench=all --bench-out="$OUT/bench_out.json" \
	> "$OUT/bench.log" 2>&1
echo "bench exit=$? $((SECONDS - t0)) s"
UDF="$X/godot/app_userdata/Crossing Europe – A Racing Xperience/leistungstest.json"
cp "$UDF" "$OUT/leistungstest_user.json" 2>/dev/null
python3 "$S/bin/bench_check.py" "$OUT/bench_out.json" "$OUT/leistungstest_user.json"
grep -E "ERROR|SCRIPT ERROR|leaked|WARNING" "$OUT/bench.log" | grep -v V-Sync | sort | uniq -c | head
X2=$S/xdg_bench_fail; rm -rf "$X2"; mkdir -p "$X2"
t0=$SECONDS
XDG_DATA_HOME=$X2 nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy --resolution 1280x720 -- --graphics=modern --no-chooser --bench=all --gfx-debug=fail \
	--bench-out="$OUT/bench_fail.json" > "$OUT/bench_fail.log" 2>&1
echo "bench_fail exit=$? $((SECONDS - t0)) s"
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print('  fallback=%r scenes=%d suggested_preset=%r suggested_mode=%r version=%r game_version=%r' % (d.get('fallback'), len(d.get('scenes',[])), d.get('suggested_preset'), d.get('suggested_mode'), d.get('version'), d.get('game_version')))" "$OUT/bench_fail.json"
echo ALLDONE
