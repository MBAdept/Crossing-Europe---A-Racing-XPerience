#!/bin/bash
# chain git merge-tree over the RINT-M2 candidates; print conflicted files per step
cd /home/user/crossing-europe---a-racing-xperience
cur=$(git rev-parse origin/wip/v080-fix-m2)
for b in "$@"; do
  out=$(git merge-tree --write-tree --name-only --no-messages "$cur" "$b" 2>&1); rc=$?
  tree=$(echo "$out" | head -1)
  echo "== + $b (rc $rc)"; echo "$out" | tail -n +2 | sed 's/^/   /'
  # synthesize a commit for the next step (parents cur and b)
  cur=$(git commit-tree "$tree" -p "$cur" -p "$(git rev-parse $b)" -m trial)
done
