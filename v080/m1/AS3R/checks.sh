#!/usr/bin/env bash
# AS3R: the two Modern checks that load models, one after the other (run_tests.sh skips them after a red unit test)
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3R/env.sh
cd "$WT"
echo "=== check_models HEAD $(git rev-parse --short HEAD) $(date +%H:%M:%S)"
timeout 900 nice -n 19 godot --headless --path . -s res://tests/race3d/check_models.gd > "$S/logs/c_models.log" 2>&1
echo "check_models exit $?"
grep -E "^CHECK|SCRIPT ERROR" "$S/logs/c_models.log"
echo "=== check_modern_stage inhalt $(date +%H:%M:%S)"
timeout 1200 nice -n 19 godot --headless --path . -s res://tests/race3d/check_modern_stage.gd -- --only=inhalt > "$S/logs/c_stage.log" 2>&1
echo "check_modern_stage exit $?"
grep -E "^CHECK|SCRIPT ERROR" "$S/logs/c_stage.log"
echo "=== Ende $(date +%H:%M:%S)"
