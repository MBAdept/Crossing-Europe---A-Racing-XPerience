#!/usr/bin/env bash
# AS2a: numbers for docs / report - inspect_models.gd once, then the validator report and the lamp table from it.
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2a
export XDG_DATA_HOME=$S/xdg
cd "$WT"
nice -n 19 godot --headless --path . -s res://tools/models/inspect_models.gd -- --out=$S/out/inspect.json > $S/logs/inspect.log 2>&1
echo "inspect exit $?"
python3 tools/blender/validate_models.py --report --inspect=$S/out/inspect.json > $S/logs/report.log 2>&1
echo "report exit $?"
python3 $S/bin/lamptable.py $S/out/inspect.json > $S/logs/lamps.log 2>&1
echo "lamps exit $?"
