#!/usr/bin/env bash
# AS3 scratch: A/B shot (Arcade | Modern) with low priority. ab.sh <name> <ab_shot args...>
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3/env.sh
cd "$WT"
NAME="$1"; shift
nice -n 19 tools/ab_shot.sh "$S/shots/$NAME" "$@" > "$S/logs/ab_$NAME.log" 2>&1
echo "exit $?"
tail -3 "$S/logs/ab_$NAME.log"
