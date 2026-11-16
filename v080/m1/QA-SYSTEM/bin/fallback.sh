#!/bin/bash
# Fallback of Modern to Arcade (contract D34, §4.4.2): --gfx-debug=fail, model manifest missing, manifest broken.
# Real game (GameFlow --stage) under Xvfb, pictures at 2 s and 6 s, log lines. The manifest is moved away only for
# the run and restored right after (git status checked at the end).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
OUT=$S/fallback
mkdir -p "$OUT"
export MESA_SHADER_CACHE_DIR=$S/mesa_fb
M=$WT/assets/models/manifest.json
run() { # name args...
	local name=$1; shift
	local x=$S/xdg_fb_$name
	rm -rf "$x"; mkdir -p "$x"
	XDG_DATA_HOME=$x nice -n 10 timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" godot --path "$WT" --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x720 -- --stage=kiel_hamburg --autopilot --screenshot="$OUT/$name" \
		--shot-times=2,6 "$@" > "$OUT/$name.log" 2>&1
	local code=$?
	local ud="$x/godot/app_userdata/Crossing Europe – A Racing Xperience"
	echo "$name exit=$code marker=$([ -f "$ud/modern_start.lock" ] && echo JA || echo nein)"
	grep -E "Modus Modern nicht|ModernRenderer|ModelDB|manifest|ERROR|SCRIPT" "$OUT/$name.log" | sort | uniq -c | head -8 | sed 's/^/    /'
}
run fail --graphics=modern --sound=modern --gfx-debug=fail
cp -p "$M" "$S/manifest.json.keep"
mv "$M" "$M.qa_away"
run nomanifest --graphics=modern
mv "$M.qa_away" "$M"
head -c 2000 "$S/manifest.json.keep" > "$M"
run brokenmanifest --graphics=modern
cp -p "$S/manifest.json.keep" "$M"
cmp "$M" "$S/manifest.json.keep" && echo "manifest restored"
# result screen note after a fallback (sample screen) and the Leistungstest with --gfx-debug=fail
x=$S/xdg_fb_result; rm -rf "$x"; mkdir -p "$x"
XDG_DATA_HOME=$x nice -n 10 timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" godot --path "$WT" --rendering-driver opengl3 \
	--audio-driver Dummy --resolution 1280x720 -- --graphics=arcade --screen=result --sample-gfx-fallback --screenshot="$OUT/result_note" \
	--shot-times=1.5 > "$OUT/result_note.log" 2>&1
echo "result_note exit=$?"
x=$S/xdg_fb_bench; rm -rf "$x"; mkdir -p "$x"
XDG_DATA_HOME=$x nice -n 10 timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" godot --path "$WT" --rendering-driver opengl3 \
	--audio-driver Dummy --resolution 1280x720 -- --graphics=modern --no-chooser --bench=all --gfx-debug=fail \
	--bench-out="$OUT/bench_fail.json" > "$OUT/bench_fail.log" 2>&1
echo "bench_fail exit=$? $(grep -o 'LEISTUNGSTEST .*' "$OUT/bench_fail.log" | cut -c1-400)"
ls "$x/godot/app_userdata/Crossing Europe – A Racing Xperience/" 2>/dev/null
cd "$WT" && git status --porcelain | head
echo ALLDONE
