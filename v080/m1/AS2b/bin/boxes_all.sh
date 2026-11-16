#!/usr/bin/env bash
# AS2b: per-group boxes of the heavy models (lod0) vs the Arcade part boxes.
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-3
P="python3 /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2b/dbg/glb_boxes.py"
for m in truck truck_transport truck_tarp; do
	G=$W/tools/blender/_cache3d/traffic/$m/model.glb
	echo "== $m (all nodes)"
	$P $G lod0/
	echo "-- $m tractor body above 1.5 m, |x|<=1.30 (cab without mirrors)"
	$P $G lod0/tractor/body --ymin=1.5 --xmax=1.30
	echo "-- $m tractor body, |x|<=1.30"
	$P $G lod0/tractor/body --xmax=1.30
	echo "-- $m lod1/lod2/shadow"
	$P $G lod1/
	$P $G lod2/
	$P $G shadow/
done
G=$W/tools/blender/_cache3d/traffic/bus/model.glb
echo "== bus"
$P $G
echo "-- bus |x|<=1.30 (without mirrors)"
$P $G lod0/ --xmax=1.30
$P $G lod1/ --xmax=1.30
$P $G lod2/ --xmax=1.30
for c in de be it at fr; do
	echo "== police/$c"
	$P $W/tools/blender/_cache3d/police/$c/model.glb lod0/body
	$P $W/tools/blender/_cache3d/police/$c/model.glb lod1/body
	$P $W/tools/blender/_cache3d/police/$c/model.glb lod2/body
done
