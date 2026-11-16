#!/bin/bash
# A/B pictures through tools/ab_shot.sh with --gfx-preset=high (Modern) and a warm shared Mesa cache.
#   ab.sh <out_dir> <name> <position or args...>       e.g. ab.sh $S/ab/r1 S1 S1   |  ab.sh $S/ab/r1 T1 --stage=...
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A/bin/env.sh
out="$1"; shift
name="$1"; shift
mkdir -p "$out"
export GFX_ARGS="${GFX_ARGS:---gfx-preset=high}"
unset XDG_DATA_HOME
start=$(date +%s)
nice -n 10 tools/ab_shot.sh "$out/$name" "$@" > "$out/$name.run.log" 2>&1
rc=$?
echo "$name rc=$rc in $(( $(date +%s) - start )) s"
grep -E "==>|FEHLER|Fehler|fiel|SCRIPT ERROR|SHADER ERROR" "$out/$name.run.log" | head -10
grep -cE "^ERROR|SCRIPT ERROR|WARNING" "$out/${name}_modern.log" 2>/dev/null | sed 's/^/modern log errors+warnings: /'
