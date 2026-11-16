#!/bin/bash
# tomut.sh – turns the base copy (R4 files) into a HEAD copy for the mutation runs: m1/NACH-R4/base -> m1/NACH-R4/mut,
# the 18 files of files_changed.txt copied from the worktree (head b156763)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-7
[ -d $S/base ] && mv $S/base $S/mut
while read -r f; do
  mkdir -p "$(dirname "$S/mut/$f")"
  cp "$WT/$f" "$S/mut/$f"
done < $S/files_changed.txt
n=0
while read -r f; do
  cmp -s "$WT/$f" "$S/mut/$f" || { echo "DIFF $f"; n=$((n+1)); }
done < $S/files_changed.txt
echo "converted, $n differences"
