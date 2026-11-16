#!/bin/bash
# mkbase.sh – copy of the worktree with the 18 FIX-R4 files at 7f0eae2 (R4 head) → m1/NACH-R4/base
set -e
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-7
B=$S/base
mkdir -p $B
(cd "$WT" && tar --exclude=./.git --exclude=./.claude -cf - .) | (cd "$B" && tar -xf -)
cd "$WT"
for f in $(git diff --name-only 7f0eae21b98f4f874e1016e50298d1e6acca2fc1 b156763cebc897f802e62471e5ee258fc7473aaf); do
  if git cat-file -e 7f0eae21b98f4f874e1016e50298d1e6acca2fc1:"$f" 2>/dev/null; then
    git show 7f0eae21b98f4f874e1016e50298d1e6acca2fc1:"$f" > "$B/$f"
  else
    rm -f "$B/$f"; echo "removed $f"
  fi
done
cd "$B"
for f in $(cd "$WT" && git diff --name-only 7f0eae21b98f4f874e1016e50298d1e6acca2fc1 b156763cebc897f802e62471e5ee258fc7473aaf); do
  if [ -f "$f" ]; then cmp -s "$f" <(cd "$WT" && git show 7f0eae21b98f4f874e1016e50298d1e6acca2fc1:"$f") && echo "ok $f"; fi
done
du -sh $B
