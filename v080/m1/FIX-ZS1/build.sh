#!/usr/bin/env bash
# FIX-ZS1: the test build from the committed head (export templates linked into the own XDG_DATA_HOME)
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-ZS1
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9559b070-4dd-1
git status --short
grep -n 'config/version' project.godot
export XDG_DATA_HOME=$S/xdg_build
ls "$XDG_DATA_HOME/godot/export_templates/4.7.2.stable/" | head -2
t0=$SECONDS
OUT=$S/testbuild nice -n 5 tools/build_testbuild.sh 0.8.0-zs1 ZS1 crossing-europe-zwischenstand
echo "exit $? ($((SECONDS - t0)) s)"
git status --short
grep -n 'config/version' project.godot
