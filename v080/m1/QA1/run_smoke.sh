#!/bin/bash
# QA1: smoke runs of the ZS1 test build with tools/smoke_modern.sh: Linux (Xvfb, OpenGL and OpenGL ES) and Windows
# (wine64). usage: run_smoke.sh [linux linux_gles windows]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-5
TB=$S/m1/QA1/testbuild
OUT=$S/m1/QA1/smoke
mkdir -p "$OUT"
cd "$WT" || exit 2
for what in ${*:-linux linux_gles windows}; do
	t0=$SECONDS
	case $what in
	linux) rm -rf "$OUT/linux"; tools/smoke_modern.sh "$TB/CrossingEurope-ZS1.x86_64" "$OUT/linux" > "$OUT/linux.out" 2>&1 ;;
	linux_gles) rm -rf "$OUT/linux_gles"; DRIVER=opengl3_es tools/smoke_modern.sh "$TB/CrossingEurope-ZS1.x86_64" "$OUT/linux_gles" > "$OUT/linux_gles.out" 2>&1 ;;
	windows) rm -rf "$OUT/windows"; mkdir -p "$OUT/windows"; WINEPREFIX=$S/m1/QA1/wineprefix tools/smoke_modern.sh "$TB/CrossingEurope-ZS1.exe" "$OUT/windows" > "$OUT/windows.out" 2>&1 ;;
	esac
	echo "$what exit=$? $((SECONDS - t0)) s"
	cat "$OUT/$what.out"
done
echo ALLDONE
