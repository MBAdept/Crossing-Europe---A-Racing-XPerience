#!/usr/bin/env bash
# FIX-WASSER-R: the test build from the committed head (export templates linked into the own XDG_DATA_HOME). The
# delivery copy into deliver/FIX-WASSER/build happens in deliver.sh (old files kept in alt/ first).
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER-R
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-3 || exit 1
echo "== build $(date -u +%T) HEAD $(git rev-parse HEAD)"
git status --short
grep -n 'config/version' project.godot
export XDG_DATA_HOME=$S/xdg_build
mkdir -p "$XDG_DATA_HOME/godot/export_templates"
[ -e "$XDG_DATA_HOME/godot/export_templates/4.7.2.stable" ] || ln -s /root/.local/share/godot/export_templates/4.7.2.stable "$XDG_DATA_HOME/godot/export_templates/4.7.2.stable"
ls "$XDG_DATA_HOME/godot/export_templates/4.7.2.stable/" | head -3
rm -rf "$S/testbuild"
t0=$SECONDS
OUT=$S/testbuild nice -n 5 tools/build_testbuild.sh 0.8.0-zs1 ZS1 crossing-europe-zwischenstand
code=$?
echo "exit $code ($((SECONDS - t0)) s)"
git status --short
grep -n 'config/version' project.godot
[ $code -eq 0 ] || exit $code
(cd "$S/testbuild" && sha256sum -c --ignore-missing SHA256SUMS)
ls -la "$S/testbuild"
cat "$S/testbuild/BUILDINFO.txt"
