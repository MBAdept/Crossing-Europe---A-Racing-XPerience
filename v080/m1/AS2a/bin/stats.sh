#!/usr/bin/env bash
# AS2a: forced export of one model with CE_STATS (triangles per object / decal cut per projection) -> logs/stats_<name>.log
# usage: stats.sh <model id> [n lines per level]
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2a
cd "$WT"
N="${2:-40}"
OUT="$S/logs/stats_$(echo "$1" | tr '/' '_').log"
CE_STATS=$N nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="$1" --jobs=1 --force > "$OUT" 2>&1
echo "exit $? -> $OUT"
grep -vE "cycles|^\s*$" "$OUT" | head -${3:-200}
