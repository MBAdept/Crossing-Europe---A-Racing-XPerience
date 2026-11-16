#!/bin/bash
# Inspect the branches to merge relative to HEAD
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-1 || exit 1
for b in origin/wip/v080-as2r origin/wip/v080-as3r origin/wip/v080-as4r f2536878c0f426e44caeb522a94ceb3adf234955; do
  echo "== $b"
  git log --oneline -1 "$b"
  mb=$(git merge-base HEAD "$b")
  echo "merge-base: $(git log --oneline -1 $mb)"
  echo "commits ahead: $(git rev-list --count $mb..$b)"
  echo "files changed vs base: $(git diff --name-only $mb $b | wc -l)"
done
