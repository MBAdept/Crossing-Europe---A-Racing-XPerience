#!/usr/bin/env bash
# NACH-R5: Modern pictures of the R5 head 5558bdc: the only code difference 5558bdc..80b8141 is
# scripts/race3d/builders/tunnel.gd – swap it in, render, restore it (always).
set -uo pipefail
N=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R5
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-8
F=scripts/race3d/builders/tunnel.gd
cd "$WT" || exit 1
restore() { git -C "$WT" checkout -- "$F"; echo "RESTORED $(git -C "$WT" status --porcelain -- scripts | wc -l) changed files in scripts"; }
trap restore EXIT
n=$(git -C "$WT" diff --name-only 5558bdc485f9df938c349e8e0ecb2f869c2335a9 80b814150bd72e5ff56714280953744b79cbb76a -- scripts assets scenes project.godot config | wc -l)
echo "code files changed 5558bdc..80b8141: $n"
git -C "$WT" show 5558bdc485f9df938c349e8e0ecb2f869c2335a9:$F > "$WT/$F"
grep -c PORTAL_LAYERS "$WT/$F"
"$N/shots.sh" base "$@"
