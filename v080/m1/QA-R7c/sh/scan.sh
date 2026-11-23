#!/bin/bash
# scan.sh <tree dir> <name> [stage list|all]: the R7c data scan in one tree
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/sh/common.sh
TREE=$1
NAME=$2
STAGES=${3:-all}
mkdir -p "$S/scan"
cd "$TREE" || exit 1
memwait
export XDG_DATA_HOME=$S/xdg_scan_$NAME
mkdir -p "$XDG_DATA_HOME"
t0=$SECONDS
nice -n 10 timeout 5400 godot --headless --path . -s "$S/probe/scan_r7c.gd" -- --stage="$STAGES" --dump="$S/scan/dump_$NAME.txt" > "$S/scan/scan_$NAME.log" 2>&1
echo "$(date -u +%H:%M:%S) scan $NAME exit=$? $((SECONDS - t0)) s" | tee -a "$S/scan/scan.out"
