#!/usr/bin/env bash
# FIX-ZS1: the test build again from the final head (docs-only commit after 634e28b), delivered and smoke-tested
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-ZS1
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/FIX-ZS1/build
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9559b070-4dd-1
echo "== build $(date -u +%T) HEAD $(git rev-parse --short HEAD)"
bash "$S/build.sh" > "$S/build2.log" 2>&1
grep -E '^exit|Commit:|Archive:|OK$' "$S/build2.log"
cp -p "$S/testbuild/CrossingEurope-ZS1-linux-x86_64.tar.gz" "$S/testbuild/CrossingEurope-ZS1-windows-x86_64.zip" "$S/testbuild/LIZENZEN.txt" \
	"$S/testbuild/SHA256SUMS" "$S/testbuild/BUILDINFO.txt" "$D/"
(cd "$D" && sha256sum -c --ignore-missing SHA256SUMS)
cat "$D/BUILDINFO.txt"
echo "== start linux $(date -u +%T)"
rm -rf "$S/smoke/start_linux" "$S/smoke/start_windows"
bash "$S/export_start.sh" linux
echo "== smoke linux $(date -u +%T)"
rm -rf "$S/smoke/lin"
MESA_SHADER_CACHE_DIR=$S/smoke/mesa_lin nice -n 5 tools/smoke_modern.sh "$S/testbuild/CrossingEurope-ZS1.x86_64" "$S/smoke/lin"
echo "exit $?"
echo "== smoke windows $(date -u +%T)"
rm -rf "$S/smoke/win"
(unset TMPDIR; nice -n 5 tools/smoke_modern.sh "$S/testbuild/CrossingEurope-ZS1.exe" "$S/smoke/win")
echo "exit $?"
echo "== start windows $(date -u +%T)"
(unset TMPDIR; bash "$S/export_start.sh" windows)
echo "== fertig $(date -u +%T)"
