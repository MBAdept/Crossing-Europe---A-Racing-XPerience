#!/bin/bash
# Gamepad-only walk (gd/qa_pad_walk.gd) under Xvfb at 1280x720 and 1280x800 with pictures and font sizes.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
export MESA_SHADER_CACHE_DIR=$S/mesa_menus
cd "$WT" || exit 2
for RES in 1280x720 1280x800; do
	OUT=$S/pad/$RES
	mkdir -p "$OUT"
	X=$S/xdg_pad_$RES; rm -rf "$X"; mkdir -p "$X"
	XDG_DATA_HOME=$X nice -n 10 timeout 400 xvfb-run -a -s "-screen 0 ${RES}x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution "$RES" -s "$S/gd/qa_pad_walk.gd" -- --no-chooser --out="$OUT" > "$OUT/run.log" 2>&1
	echo "$RES exit=$?"
	grep -E "WINDOW|FONT|CHECK|QA-PAD|SCRIPT ERROR" "$OUT/run.log" | cut -c1-260
done
