#!/usr/bin/env bash
# FIX-ZS1: everything with the exported builds, one after the other: start pictures (Linux), smoke Linux, smoke Linux
# OpenGL ES, smoke Windows (Wine; creates the prefix), start pictures (Windows), first start like a player (chooser walk)
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-ZS1
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9559b070-4dd-1
mkdir -p "$S/smoke"
echo "== start linux $(date -u +%T)"
bash "$S/export_start.sh" linux
echo "== smoke linux $(date -u +%T)"
MESA_SHADER_CACHE_DIR=$S/smoke/mesa_lin nice -n 5 tools/smoke_modern.sh "$S/testbuild/CrossingEurope-ZS1.x86_64" "$S/smoke/lin"
echo "exit $?"
echo "== smoke linux opengl3_es $(date -u +%T)"
DRIVER=opengl3_es MESA_SHADER_CACHE_DIR=$S/smoke/mesa_gles nice -n 5 tools/smoke_modern.sh "$S/testbuild/CrossingEurope-ZS1.x86_64" "$S/smoke/gles"
echo "exit $?"
echo "== smoke windows $(date -u +%T)"
(unset TMPDIR; nice -n 5 tools/smoke_modern.sh "$S/testbuild/CrossingEurope-ZS1.exe" "$S/smoke/win")
echo "exit $?"
echo "== start windows $(date -u +%T)"
(unset TMPDIR; bash "$S/export_start.sh" windows)
echo "== walk $(date -u +%T)"
bash "$S/chooser_walk.sh"
echo "== fertig $(date -u +%T)"
