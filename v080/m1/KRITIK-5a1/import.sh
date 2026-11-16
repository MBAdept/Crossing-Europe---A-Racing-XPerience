#!/usr/bin/env bash
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a1/env.sh
cd "$T"; waitmem
start=$(date +%s)
timeout 2400 nice -n 19 godot --headless --path . --import > "$K/logs/import.log" 2>&1
echo "import exit $? $(( $(date +%s) - start )) s"
grep -cE "ERROR|SCRIPT ERROR" "$K/logs/import.log"
grep -E "ERROR" "$K/logs/import.log" | head -10
