#!/usr/bin/env bash
# KRITIK-4: import the scratch copy once (headless, nice 19)
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-4/env.sh
cd "$T"
start=$(date +%s)
timeout 1800 nice -n 19 godot --headless --path . --import > "$K/logs/import.log" 2>&1
echo "import exit $? $(( $(date +%s) - start )) s"
grep -cE "ERROR|SCRIPT ERROR" "$K/logs/import.log"
grep -E "ERROR" "$K/logs/import.log" | head -10
