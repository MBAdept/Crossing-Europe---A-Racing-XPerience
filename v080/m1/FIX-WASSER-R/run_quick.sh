#!/bin/bash
# Quick checks after an edit: compile check, props unit tests, terrain plan dump (one at a time, nice 5).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER-R
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-3
export XDG_DATA_HOME=$S/xdg
cd "$W" || exit 1
echo "== check_scripts"
nice -n 5 godot --headless --path . -s res://tests/check_scripts.gd 2>&1 | tail -5
echo "== test_props"
nice -n 5 tools/run_tests.sh test_props 2>&1 | grep -E '^(ok|FAIL|  )|Tests|fehl' | tail -30
echo "== terrain plan dump"
rm -rf "$S/dump"
nice -n 5 timeout 900 godot --headless --path . -s res://tests/race3d/check_terrain_plan.gd -- --dump="$S/dump" 2>&1 | grep -E 'CHECK|ERROR|Error|FEHLER' | head -20
python3 - "$S/dump" <<'EOF'
import json, sys, glob, os
for f in sorted(glob.glob(os.path.join(sys.argv[1], 'plan_*.json'))):
    d = json.load(open(f))
    print(os.path.basename(f), 'far_y', round(d['far_y'], 3), 'km', round(d['km'], 2))
EOF
echo "== done"
