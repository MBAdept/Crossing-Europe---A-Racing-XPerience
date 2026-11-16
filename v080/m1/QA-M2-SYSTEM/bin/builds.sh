#!/bin/bash
# Both exports from the gate worktree (build/ is git-ignored), the size table (tools/pck_report.py), then the Windows
# build under wine64 in Arcade and Modern (tools/smoke_modern.sh) and the Linux build (smoke). Sequential, nice 10.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4
OUT=$S/builds
mkdir -p "$OUT"
X=$S/xdg_build; mkdir -p "$X/godot"
[ -e "$X/godot/export_templates" ] || ln -s /root/.local/share/godot/export_templates "$X/godot/export_templates"
cd "$WT" || exit 2
t0=$SECONDS
XDG_DATA_HOME=$X nice -n 10 tools/build_linux.sh > "$OUT/build_linux.log" 2>&1
echo "build_linux exit=$? $((SECONDS - t0)) s"
t0=$SECONDS
XDG_DATA_HOME=$X nice -n 10 tools/build_windows.sh > "$OUT/build_windows.log" 2>&1
echo "build_windows exit=$? $((SECONDS - t0)) s"
ls -la build/ | head
tail -30 "$OUT/build_windows.log"
git status --porcelain | head -5
echo ALLDONE
