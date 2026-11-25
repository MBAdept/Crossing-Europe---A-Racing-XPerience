#!/bin/bash
# QA-MID: the same race-run photos in the FIX tree (stage_shots.gd, seed 7, timescale 40), cut off after MAXS wall seconds
# fixrace.sh <tag> <stage> <from> <hour> <weather> <shot kms>  -> fix/race/<tag>/s_kmNNN.N.png
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/sh/env.sh
F=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/qamid-fix
tag=$1; out=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/fix/race/$tag; mkdir -p $out; x=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/xdg/fixrace; rm -rf $x; mkdir -p $x
t0=$SECONDS
(cd $F && XDG_DATA_HOME=$x nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy --resolution 1280x720 -s /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/sh/stage_shots.gd -- --stage=$2 --from=$3 --hour=$4 --weather=$5 --seed=7 \
	--timescale=40 --max-seconds=${MAXS:-150} --graphics=modern --gfx-preset=high ${EXTRA:-} --shot-km=$6 --out=$out/s > $out/run.log 2>&1)
echo "$(date +%T) fixrace $tag exit=$? $((SECONDS - t0)) s shots=$(ls $out | grep -c png)" >> /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID/logs/fix.log
