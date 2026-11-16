#!/bin/bash
# tools/run_tests.sh [filter] with the RINT-A environment; log to $S/logs/rt_<filter|all>.log
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A/bin/env.sh
name=${1:-all}
start=$(date +%s)
if [ $# -gt 0 ]; then
  nice -n 10 tools/run_tests.sh "$1" > "$S/logs/rt_$name.log" 2>&1
else
  nice -n 10 tools/run_tests.sh > "$S/logs/rt_$name.log" 2>&1
fi
rc=$?
echo "rc=$rc in $(( $(date +%s) - start )) s  (log $S/logs/rt_$name.log)"
grep -E "FEHLER|fehlgeschlagen|FAILED|SCRIPT ERROR|Parse Error|==>|Tests:|tests,|bestanden" "$S/logs/rt_$name.log" | head -40
