#!/bin/bash
# Fallback of Modern to Arcade (contract D34, §4.4.2): --gfx-debug=fail, model manifest missing, manifest broken,
# one model file missing. Real game (GameFlow --stage) under Xvfb, pictures at 3 s and 8 s, log lines. Runs in the
# SCRATCH COPY $S/mut (the manifest is moved there, never in the gate worktree); restored and compared at the end.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
M=$S/mut
OUT=$S/fallback
mkdir -p "$OUT"
export MESA_SHADER_CACHE_DIR=$S/mesa_fb
MF=$M/assets/models/manifest.json
run() { # name args...
	local name=$1; shift
	local x=$S/xdg_fb_$name
	rm -rf "$x"; mkdir -p "$x"
	local t0=$SECONDS
	XDG_DATA_HOME=$x nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path "$M" --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x720 -- --stage=kiel_hamburg --autopilot --gfx-preset=medium --screenshot="$OUT/$name" \
		--shot-times=3,8 "$@" > "$OUT/$name.log" 2>&1
	local code=$?
	local ud="$x/godot/app_userdata/Crossing Europe – A Racing Xperience"
	echo "$name exit=$code $((SECONDS - t0)) s marker=$([ -f "$ud/modern_start.lock" ] && echo JA || echo nein)"
	grep -E "Modus|ModernRenderer|ModelDB|manifest|Manifest|ERROR|SCRIPT|fallback|Rückfall|selftest" "$OUT/$name.log" | sort | uniq -c | head -10 | sed 's/^/    /'
}
cp -p "$MF" "$S/manifest.json.keep"
run fail --graphics=modern --sound=modern --gfx-debug=fail
mv "$MF" "$MF.qa_away"
run nomanifest --graphics=modern
mv "$MF.qa_away" "$MF"
head -c 3000 "$S/manifest.json.keep" > "$MF"
run brokenmanifest --graphics=modern
cp -p "$S/manifest.json.keep" "$MF"
# one mesh of the player car missing (a damaged install): stand-in or fallback, never a crash
P=$M/assets/models/player/limousine/lod0_body.res
if [ -f "$P" ]; then
	mv "$P" "$P.qa_away"
	run nomesh --graphics=modern --vehicle=limousine
	mv "$P.qa_away" "$P"
fi
cmp "$MF" "$WT/assets/models/manifest.json" && echo "manifest restored (= worktree)"
diff -rq "$M/assets/models" "$WT/assets/models" | head -5
echo ALLDONE
