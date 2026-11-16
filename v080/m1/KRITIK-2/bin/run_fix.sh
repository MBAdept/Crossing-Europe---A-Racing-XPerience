#!/usr/bin/env bash
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-2
for b in p s x t; do
  echo "== fix $b $(date +%T)"
  $S/bin/run_jobs.sh $S/jobs/$b.json $S/out/tiles/$b --skip-existing
done
echo "== fix done $(date +%T)"
