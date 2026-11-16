#!/bin/bash
# Lead: remove finished, clean, pushed worktrees (M1 assembly/QA, AS3/AS4 first builds) and their local branches
set -u
cd /home/user/crossing-europe---a-racing-xperience
for w in wf_ae4df3ba-14f-1 wf_ae4df3ba-14f-2 wf_ae4df3ba-14f-3 wf_ae4df3ba-14f-4 wf_ae4df3ba-14f-5 wf_aad8d49e-fb4-1 wf_aad8d49e-fb4-2; do
  p=.claude/worktrees/$w
  [ -d "$p" ] || { echo "skip $w (missing)"; continue; }
  if [ -n "$(git -C "$p" status --porcelain)" ]; then echo "skip $w (dirty)"; continue; fi
  git worktree remove "$p" && git branch -D "worktree-$w" >/dev/null && echo "removed $w"
done
git worktree prune
df -h / | tail -1
