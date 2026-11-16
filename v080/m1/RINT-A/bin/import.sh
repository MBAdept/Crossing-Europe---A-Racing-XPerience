#!/bin/bash
# headless import of the worktree; log to $S/logs/import.log
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-A/bin/env.sh
start=$(date +%s)
nice -n 10 godot --headless --path . --import > "$S/logs/import.log" 2>&1
rc=$?
echo "import rc=$rc in $(( $(date +%s) - start )) s"
grep -iE "error|warning|failed" "$S/logs/import.log" | head -40
git status --short | head -30
