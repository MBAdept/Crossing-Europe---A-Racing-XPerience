#!/bin/bash
# batch.sh <outdir> <preset> <shot-times> POS... – A/B pairs one after the other on the worktree
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
OUT=$1; PRESET=$2; TIMES=$3; shift 3
mkdir -p "$OUT"
for p in "$@"; do
  echo "== $p $(date +%T)"
  "$R4/sh/ab.sh" "$OUT" "$p" "$p" "$PRESET" --shot-times="$TIMES" > "$OUT/$p.out" 2>&1
  echo "   exit=$? $(date +%T)"
  grep -hE 'SCRIPT ERROR|ERROR:|Shader|shader' "$OUT/${p}_modern.log" 2>/dev/null | head -5
done
echo DONE
