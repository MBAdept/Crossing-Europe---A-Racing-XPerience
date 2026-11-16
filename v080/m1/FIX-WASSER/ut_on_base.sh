#!/bin/bash
# Runs tests/unit/race3d/test_far_ground_water.gd against the far_ground.gd of the base 3a23cb8 (the test must fail
# there), then restores the working copy's file.
set -u
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-1
SC=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER
export XDG_DATA_HOME=$SC/xdg
cd "$WT" || exit 1
cp scripts/race3d/layers/far_ground.gd "$SC/far_ground.gd.new"
git show 3a23cb8dad346b623118fc0bcab9c0ffaea1efbf:scripts/race3d/layers/far_ground.gd > scripts/race3d/layers/far_ground.gd
nice -n 10 timeout 600 godot --headless --path . -s res://tests/run_tests.gd -- --filter=test_far_ground_water > "$SC/ut_on_base.log" 2>&1
echo "exit $?" >> "$SC/ut_on_base.log"
cp "$SC/far_ground.gd.new" scripts/race3d/layers/far_ground.gd
git diff --stat
