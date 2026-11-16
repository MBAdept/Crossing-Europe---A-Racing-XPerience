#!/bin/bash
# Linux and Windows exports of this tree (tools/build_linux.sh, tools/build_windows.sh incl. pck_report size table and
# gate). Export templates are found through a scratch XDG folder that links the real template folder.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
X=$S/xdg_build
mkdir -p "$X/godot"
[ -e "$X/godot/export_templates" ] || ln -s /root/.local/share/godot/export_templates "$X/godot/export_templates"
cd "$WT" || exit 2
t0=$SECONDS
XDG_DATA_HOME=$X nice -n 10 tools/build_linux.sh > "$S/build_linux.log" 2>&1
echo "linux exit=$? $((SECONDS - t0)) s"
t0=$SECONDS
XDG_DATA_HOME=$X nice -n 10 tools/build_windows.sh > "$S/build_windows.log" 2>&1
echo "windows exit=$? $((SECONDS - t0)) s"
ls -la build/
git status --porcelain | head
echo ALLDONE
