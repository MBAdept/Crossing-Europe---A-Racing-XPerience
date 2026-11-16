#!/usr/bin/env bash
# FIX-WASSER: everything with the exported builds, one after the other: start + bridge pictures (Linux), smoke Linux,
# smoke Linux OpenGL ES, smoke Windows (Wine; creates the prefix), start + bridge pictures (Windows), first start like a
# player (chooser walk)
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-1 || exit 1
mkdir -p "$S/smoke"
echo "== export linux $(date -u +%T)"
bash "$S/export_shots.sh" linux
echo "== smoke linux $(date -u +%T)"
rm -rf "$S/smoke/lin"
MESA_SHADER_CACHE_DIR=$S/smoke/mesa_lin nice -n 5 tools/smoke_modern.sh "$S/testbuild/CrossingEurope-ZS1.x86_64" "$S/smoke/lin"
echo "exit $?"
echo "== smoke linux opengl3_es $(date -u +%T)"
rm -rf "$S/smoke/gles"
DRIVER=opengl3_es MESA_SHADER_CACHE_DIR=$S/smoke/mesa_gles nice -n 5 tools/smoke_modern.sh "$S/testbuild/CrossingEurope-ZS1.x86_64" "$S/smoke/gles"
echo "exit $?"
echo "== smoke windows $(date -u +%T)"
rm -rf "$S/smoke/win"
(unset TMPDIR; nice -n 5 tools/smoke_modern.sh "$S/testbuild/CrossingEurope-ZS1.exe" "$S/smoke/win")
echo "exit $?"
echo "== export windows $(date -u +%T)"
(unset TMPDIR; bash "$S/export_shots.sh" windows)
echo "== walk $(date -u +%T)"
bash "$S/chooser_walk.sh"
echo "== fertig $(date -u +%T)"
