#!/bin/bash
# start zs2_build.sh once the fix clips and the render checks of the fix head are done (build_testbuild.sh patches
# project.godot during the export – nothing else may run in F meanwhile)
Q=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID
until grep -q "CLIPSFIX DONE" $Q/logs/media.log && grep -q "FIXGATES DONE" $Q/logs/fix.log; do sleep 30; done
bash $Q/sh/zs2_build.sh
