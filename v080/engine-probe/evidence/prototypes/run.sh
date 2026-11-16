#!/usr/bin/env bash
# Usage: [OVERRIDE=$'[rendering]\nkey=value'] [TAG=name] run.sh <suite> [test] [extra godot args...]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/engine-probe
SUITE=$1; TEST=${2:-}; shift; shift || true
mkdir -p $S/shots $S/logs
rm -f $S/probe/override.cfg
if [ -n "${OVERRIDE:-}" ]; then printf '%s\n' "$OVERRIDE" > $S/probe/override.cfg; fi
OUT=$S/shots${TAG:+/$TAG}; mkdir -p $OUT
XDG_DATA_HOME=${XDGDIR:-$S/xdg} timeout ${TMO:-300} xvfb-run -a -s "-screen 0 ${SCREEN:-1280x720}x24" godot --path $S/probe --rendering-driver ${DRIVER:-opengl3} --audio-driver Dummy --resolution ${SCREEN:-1280x720} "$@" -- --suite=$SUITE --test=$TEST --out=$OUT 2>&1 | grep -vE "^ALSA|V-Sync|set_use_vsync|^\s*$" | tee $S/logs/${SUITE}_${TEST:-all}${TAG:+_$TAG}.log
rm -f $S/probe/override.cfg
