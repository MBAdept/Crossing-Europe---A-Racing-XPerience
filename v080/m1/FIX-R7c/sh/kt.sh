#!/bin/bash
# FIX-R7c: run a review scene (R7c's kt copies + fx_scene, installed UNTRACKED into tools/kritik/ of the worktree).
#   kt.sh <script> <name> <args...>   -> $S/kt_out/<name>.png + .log
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7c/sh/common.sh
R=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c/kt
T=$WT/tools/kritik
mkdir -p "$T" "$S/kt_out"
cp "$R/prop_scene_as3.gd" "$T/prop_scene_as3.gd"
sed 's#extends "res://tools/models/prop_scene.gd"#extends "res://tools/kritik/prop_scene_as3.gd"#' "$R/kritik_scene.gd" > "$T/kritik_scene.gd"
for f in k4_scene.gd k5_scene.gd k6_scene.gd my_scene.gd; do cp "$R/$f" "$T/$f"; done
cp "$S/kt/fx_scene.gd" "$T/fx_scene.gd"
scr=$1
shift
name=$1
shift
memwait
t0=$SECONDS
cd "$WT" || exit 1
XDG_DATA_HOME=$S/xdg_kt nice -n 10 timeout 3600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy -s "res://tools/kritik/$scr.gd" -- "--out=$S/kt_out/$name.png" "$@" > "$S/kt_out/$name.log" 2>&1
echo "$name exit $? $((SECONDS - t0)) s"
grep -E "^(FLIMMER|LODCOL)|SCRIPT ERROR|SHADER ERROR|Parse" "$S/kt_out/$name.log" | awk '!seen[$0]++' | head -60
