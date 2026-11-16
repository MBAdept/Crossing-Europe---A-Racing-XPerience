#!/bin/bash
# Re-export and bake the truck (retro channel 15), then import, manifest and validator.
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-1
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-B
cd "$WT" || exit 1
export XDG_DATA_HOME=$S/xdg_bake
mkdir -p "$XDG_DATA_HOME"
nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only='traffic/truck' --jobs=1 > "$S/export_truck.log" 2>&1
echo "export exit=$?"; tail -2 "$S/export_truck.log"
nice -n 10 timeout 900 godot --headless --path . -s res://tools/models/bake_models.gd -- --only='traffic/truck' > "$S/bake_truck.log" 2>&1
echo "bake exit=$?"; grep -E "ERROR|FEHLER" "$S/bake_truck.log" | head -5
nice -n 10 timeout 900 godot --headless --path . --import > "$S/import_truck.log" 2>&1
echo "import exit=$?"
python3 tools/blender/export_models.py --manifest-only
python3 tools/blender/validate_models.py 2>&1 | tail -4
