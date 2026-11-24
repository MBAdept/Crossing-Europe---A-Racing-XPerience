#!/bin/bash
# RINT-M3 (copy of RINT-M2): export determinism – two AS5a models (merged with AS5aR1) exported twice with --force (cache folders byte-equal)
# and baked: the baked model folders must equal the committed ones.
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_a71eeb2e-3b7-1
cd $W || exit 2
H() { (cd "$1" && find . -type f ! -name '*_report.json' -print0 | sort -z | xargs -0 sha256sum | sha256sum | cut -c1-16); }
for m in props/city_hanse_kontor props/city_german_house; do
	n=${m#props/}
	a0=$(H assets/models/props/$n)
	CE_THREADS=2 nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only=$m --force --jobs=1 2>&1 | tail -2
	c0=$(H tools/blender/_cache3d/props/$n)
	CE_THREADS=2 nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --only=$m --force --jobs=1 2>&1 | tail -2
	nice -n 10 godot --headless --path . -s res://tools/models/bake_models.gd -- --only=$m 2>&1 | tail -2
	c1=$(H tools/blender/_cache3d/props/$n)
	a1=$(H assets/models/props/$n)
	echo "DET $m cache $c0 -> $c1 $([ "$c0" = "$c1" ] && echo gleich || echo ANDERS); assets $a0 -> $a1 $([ "$a0" = "$a1" ] && echo gleich || echo ANDERS)"
done
echo "git status assets/models: $(git status --porcelain assets/models | wc -l) geänderte Dateien"
