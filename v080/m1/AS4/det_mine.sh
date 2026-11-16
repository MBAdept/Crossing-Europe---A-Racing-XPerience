#!/usr/bin/env bash
# AS4 scratch: determinism - forced re-export of the AS4 models, bake, import, manifest; afterwards the working tree
# must be clean (byte-identical files; run on a committed state).
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-2
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS4
cd "$WT"
echo "=== vorher: $(git status --porcelain | wc -l) geänderte Dateien"
t0=$(date +%s)
"$S/export_mine.sh" --force "$@"
echo "=== Export + Bake + Import + Manifest: $(( $(date +%s) - t0 )) s"
echo "=== git status (leer = byte-identisch)"
git status --porcelain
echo "=== Ende"
