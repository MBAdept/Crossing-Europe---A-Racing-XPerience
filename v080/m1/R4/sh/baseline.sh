#!/bin/bash
# Baseline A/B pictures on the base commit (before R4 changes)
R4=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4
OUT=$R4/shots/base
mkdir -p "$OUT"
for p in N1 N2 N2N C1 DEV S1DAWN S1DUSK S1OVC TEXIT; do
  echo "== $p $(date +%T)"
  "$R4/sh/ab.sh" "$OUT" "$p" "$p" high --shot-times=3 > "$OUT/$p.out" 2>&1
  echo "   exit=$? $(date +%T)"
done
echo DONE
