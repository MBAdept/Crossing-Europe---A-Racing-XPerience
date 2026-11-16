#!/usr/bin/env bash
# AS5aR1: run a review scene script under Xvfb.  k5.sh <script> <name> <args...>
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2/env.sh
cd "$WT"
scr=$1; shift
name=$1; shift
waitmem
start=$(date +%s)
mkdir -p "$(dirname "$S/shots/$name.png")" "$(dirname "$S/logs/$name.log")"
timeout 3600 nice -n 19 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	-s res://tools/kritik/$scr.gd -- "--out=$S/shots/$name.png" "$@" > "$S/logs/$name.log" 2>&1
rc=$?
echo "$name exit $rc $(( $(date +%s) - start )) s"
grep -E "^(FLIMMER|UMRISS|STUFEN|STUFE|UMSCHALT|SPARK|SZENE|TINT|TEXEL|k4_scene|k5_scene|kritik_scene|prop_scene|my_scene)|ERROR|SCRIPT|Parse" "$S/logs/$name.log" | awk '!seen[$0]++' | head -80
