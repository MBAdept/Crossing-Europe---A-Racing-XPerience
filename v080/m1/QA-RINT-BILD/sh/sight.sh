#!/bin/bash
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD/sh/env.sh
ROOT=${1:-$W}
TAG=${2:-head}
export XDG_DATA_HOME=$S/xdg/sight_$TAG; mkdir -p $XDG_DATA_HOME
cd $ROOT
t0=$SECONDS
nice -n 10 godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full > $S/logs/sight_full_$TAG.log 2>&1; echo "exit=$? $((SECONDS-t0))s" >> $S/logs/sight_full_$TAG.log
t0=$SECONDS
nice -n 10 godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full > $S/logs/path_full_$TAG.log 2>&1; echo "exit=$? $((SECONDS-t0))s" >> $S/logs/path_full_$TAG.log
