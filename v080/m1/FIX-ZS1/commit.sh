#!/usr/bin/env bash
# usage: commit.sh <message file>  – commits all tracked + new files under the given paths (git add -A) and pushes the
# safety copy to origin wip/v080-fix-zs1
set -euo pipefail
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9559b070-4dd-1
git add -A scripts tests tools docs config 2>/dev/null || true
git status --short | head -40
git commit -F "$1"
git push origin HEAD:refs/heads/wip/v080-fix-zs1 2>&1 | tail -3
git log --oneline -1
