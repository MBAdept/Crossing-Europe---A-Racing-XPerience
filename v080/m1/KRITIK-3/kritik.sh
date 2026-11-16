#!/usr/bin/env bash
# KRITIK-3: run tools/kritik/kritik_scene.gd (scratch copy) under Xvfb. kritik.sh <name> <args...>
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-3/env.sh
cd "$T"
name=$1; shift
start=$(date +%s)
timeout 1500 nice -n 19 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
	-s res://tools/kritik/kritik_scene.gd -- "--out=$K/shots/$name.png" "$@" > "$K/logs/$name.log" 2>&1
rc=$?
echo "$name exit $rc $(( $(date +%s) - start )) s"
grep -E "^(FLIMMER|UMRISS|STUFEN|UMSCHALT|SZENE|PEGEL|SPRUNG|kritik_scene|prop_scene)|ERROR|SCRIPT|Parse" "$K/logs/$name.log" | awk '!seen[$0]++' | head -60
