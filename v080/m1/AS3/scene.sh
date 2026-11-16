#!/usr/bin/env bash
# AS3 scratch: review scene with low priority. scene.sh <out.png> <prop_scene args...>
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3/env.sh
cd "$WT"
OUT="$1"; shift
case "$OUT" in /*) ;; *) OUT="$S/shots/$OUT" ;; esac
nice -n 19 tools/models/prop_scene.sh "$OUT" "$@" 2>&1 | grep -v "^$"
