#!/usr/bin/env bash
# R7c: run a review scene script (kt copies, installed UNTRACKED into tools/kritik/) under Xvfb.  k5.sh <script> <name> <args...>
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c/env.sh
T=$WT/tools/kritik
mkdir -p "$T"
cp "$S/kt/prop_scene_as3.gd" "$T/prop_scene_as3.gd"
sed 's#extends "res://tools/models/prop_scene.gd"#extends "res://tools/kritik/prop_scene_as3.gd"#' "$S/kt/kritik_scene.gd" > "$T/kritik_scene.gd"
for f in k6_scene.gd k4_scene.gd k5_scene.gd my_scene.gd k7_scene.gd; do
  if [ -f "$S/kt/$f" ]; then cp "$S/kt/$f" "$T/$f"; fi
done
cd "$WT"
scr=$1; shift
name=$1; shift
waitmem
start=$(date +%s)
mkdir -p "$(dirname "$S/shots/$name.png")" "$(dirname "$S/logs/$name.log")"
timeout 3600 nice -n 10 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	-s res://tools/kritik/$scr.gd -- "--out=$S/shots/$name.png" "$@" > "$S/logs/$name.log" 2>&1
rc=$?
echo "$name exit $rc $(( $(date +%s) - start )) s"
grep -E "^(FLIMMER|LODCOL|STUFEN|SWAP|k[4-7]_scene|kritik_scene|prop_scene|my_scene)|SCRIPT ERROR|SHADER ERROR|Parse" "$S/logs/$name.log" | awk '!seen[$0]++' | head -80
