#!/usr/bin/env bash
# AS2R: try far glazing looks (TRAFFIC_GLASS_FAR) for van + sports: export, bake, render lod1 at 40 m (1x + ss4),
# compare with the lod0 tiles of probe p40a.  usage: glass_exp.sh '<python dict>' <tag>
set -uo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-4
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2R
K=$S/kritik
VAR=$1; TAG=$2
cd "$WT"
sed -i "s/^TRAFFIC_GLASS_FAR = .*/TRAFFIC_GLASS_FAR = $VAR/" tools/blender/ce3d/traffic3d.py
grep -n "^TRAFFIC_GLASS_FAR" tools/blender/ce3d/traffic3d.py
export XDG_DATA_HOME=$S/xdg
for m in van sports; do
	nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only="traffic/$m" --jobs=1 --force 2>&1 | grep -E "EXPORT|Error|raise"
	nice -n 19 godot --headless --path . -s res://tools/models/bake_models.gd -- --only="traffic/$m" > /dev/null 2>&1
done
python3 tools/blender/export_models.py --manifest-only > /dev/null
mkdir -p "$K/out/$TAG"
cp "$K/out/p40a/"*lod0* "$K/out/p40a/"*lod1_clay* "$K/out/p40a/"*lod1_mask* "$K/out/p40a/empty_day.png" "$K/out/$TAG/"
python3 - "$K/jobs/p40a.json" "$K/jobs/$TAG.json" <<'EOF'
import json, sys
J = [j for j in json.load(open(sys.argv[1])) if "_lod1" in j["name"] and ("clay" not in j["name"]) and ("mask" not in j["name"])]
json.dump(J, open(sys.argv[2], "w"))
EOF
$K/run_jobs.sh "$K/jobs/$TAG.json" "$K/out/$TAG" | tail -1
for s in van_white sports_red; do
	python3 $K/bin/winmean.py "$K/out/$TAG" $s 40 lod0 lod1
	python3 $K/bin/probe_sheet.py "$K/out/$TAG" $s 40 lod0 lod1 "$K/sheets/${TAG}_$s.jpg" 2>/dev/null | head -1
done
