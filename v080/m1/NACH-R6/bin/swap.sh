#!/usr/bin/env bash
# NACH-R6: put the three builders of a commit into the worktree (base = c8b18d1, head = 2b7dcc0). Only these three
# script files differ between the two commits (git diff --stat c8b18d1..2b7dcc0). Prints the resulting status.
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-4
REV=${1:?base|head}
case "$REV" in
base) C=c8b18d1 ;;
head) C=2b7dcc0 ;;
*) echo "base|head"; exit 2 ;;
esac
cd "$W" || exit 1
for f in scripts/race3d/builders/border.gd scripts/race3d/builders/gantry.gd scripts/race3d/builders/station.gd; do
	git show "$C:$f" > "$f"
done
git status --short
