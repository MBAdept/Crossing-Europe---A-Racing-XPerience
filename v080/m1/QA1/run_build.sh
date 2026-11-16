#!/bin/bash
# QA1: test build ZS1 (tools/build_testbuild.sh) with export templates found through a scratch XDG folder.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-5
X=$S/m1/QA1/xdg_build
mkdir -p "$X/godot"
[ -e "$X/godot/export_templates" ] || ln -s /root/.local/share/godot/export_templates "$X/godot/export_templates"
cd "$WT" || exit 2
t0=$SECONDS
OUT=$S/m1/QA1/testbuild XDG_DATA_HOME=$X nice -n 10 tools/build_testbuild.sh 0.8.0-zs1 ZS1 crossing-europe-zwischenstand \
	> "$S/m1/QA1/build_testbuild.log" 2>&1
echo "build exit=$? $((SECONDS - t0)) s"
tail -25 "$S/m1/QA1/build_testbuild.log"
git status --porcelain
echo ALLDONE
