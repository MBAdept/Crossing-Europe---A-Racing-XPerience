#!/usr/bin/env bash
# KRITIK-4: run tools/models/prop_scene.sh (AS3 version with --look=race) in the scratch copy.
# ps.sh <name> <args...>   -> $K/shots/<name>.png, log $K/logs/<name>.log
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-4/env.sh
cd "$T"
name=$1; shift
start=$(date +%s)
nice -n 19 tools/models/prop_scene.sh "$K/shots/$name.png" "$@" > "$K/logs/$name.log" 2>&1
rc=$?
echo "$name exit $rc $(( $(date +%s) - start )) s"
grep -E "STUFEN|UMSCHALT|ERROR|SCRIPT|Parse|FEHLER|Renn-Licht" "$K/logs/$name.log" | head -40
