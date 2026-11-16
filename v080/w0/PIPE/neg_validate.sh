#!/bin/bash
# scratch: does the validator bite? Three planted errors, each must end in "CHECK models FEHLER"; the
# repository is restored after each.
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_92c01fa2-b2a-2
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE
export XDG_DATA_HOME=$D/xdg
cd $W
echo "== 1 manifest differs from the fragments (tris of the streetlight changed in manifest.json)"
cp assets/models/manifest.json $D/manifest.keep
sed -i 's/"tris": 312/"tris": 313/' assets/models/manifest.json
python3 tools/blender/validate_models.py --no-godot | grep -E "FEHLER|CHECK"
cp $D/manifest.keep assets/models/manifest.json
echo "== 2 a mesh file changed after the bake (one byte appended to the streetlight mesh)"
cp assets/models/props/streetlight/lod0_body.res $D/streetlight.keep
printf 'x' >> assets/models/props/streetlight/lod0_body.res
python3 tools/blender/validate_models.py --no-godot | grep -E "FEHLER|CHECK"
cp $D/streetlight.keep assets/models/props/streetlight/lod0_body.res
echo "== 3 decoded vertex data off their values (paint code 0.3, lamp channel 5.2, atlas UV 1.4 planted in the inspect report)"
python3 - <<EOF
import json
r = json.load(open("$D/inspect.json"))
r["meshes"]["traffic/sedan/lod0_body.res"]["surfaces"][0]["alpha_values"].append(0.3)
r["meshes"]["traffic/sedan/lod0_body.res"]["surfaces"][0]["lamp_values"].append(5.2)
r["meshes"]["props/farmhouse/lod0_body.res"]["surfaces"][0]["uv_range"][2] = 1.4
r["meshes"]["player/limousine/lod0_body.res"]["surfaces"][0]["lods"] = 2
r["meshes"]["traffic/sedan/wheel.res"]["aabb"][1] = -0.30
json.dump(r, open("$D/inspect_bad.json", "w"))
EOF
python3 tools/blender/validate_models.py --inspect=$D/inspect_bad.json | grep -E "FEHLER|CHECK"
echo "== after restoring"
python3 tools/blender/validate_models.py --inspect=$D/inspect.json | grep -E "FEHLER|CHECK"
git -C $W status --short assets/models
