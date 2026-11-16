#!/bin/bash
# Extract read-only copies of selected files of both builds into the scratch folder (no checkout, no git state change).
set -e
REPO=/home/user/crossing-europe---a-racing-xperience
OUT=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/CLIP-ANALYSE/src
ZS1=39849f0263921f798da4326b83dff30d83a947d2
M2=6e484056ec87e2fa614061000a362feb2b5a6db8
cd "$REPO"
for tag in zs1 m2; do
  if [ "$tag" = zs1 ]; then C=$ZS1; else C=$M2; fi
  for p in "$@"; do
    mkdir -p "$OUT/$tag/$(dirname "$p")"
    if git cat-file -e "$C:$p" 2>/dev/null; then
      git show "$C:$p" > "$OUT/$tag/$p"
    else
      echo "missing in $tag: $p"
    fi
  done
done
