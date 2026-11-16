#!/bin/bash
# QA-M2-BILD: vegetation levels and buildings through tools/models/prop_scene.sh (race look, preset medium: lod0 ->
# lod1 at 60 m, lod1 -> impostor at 200 m, the Arcade sprite beside) at noon and night; buildings at night.
# Output shots/veg/. Idempotent.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-3
O=$S/shots/veg
mkdir -p $O $S/tmp
export TMPDIR=$S/tmp
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
M=props/tree_oak,props/tree_birch,props/tree_beech,props/tree_pine,props/tree_spruce,props/tree_poplar,props/tree_cypress,props/tree_olive,props/tree_palm,props/bush_round
for h in 12 19.5; do
	f=$O/lods_h${h}.png
	[ -s "$f" ] && { echo "skip veg $h"; continue; }
	x=$S/xdg/veg_$h
	rm -rf "$x"; mkdir -p "$x"
	t0=$SECONDS
	(cd $WT && XDG_DATA_HOME=$x nice -n 10 tools/models/prop_scene.sh "$f" --mode=lods --look=race --hour=$h --preset=medium \
		--sprite --models=$M > "$O/lods_h${h}.log" 2>&1)
	echo "$(date -u +%H:%M:%S) veg lods $h exit=$? $((SECONDS - t0)) s"
	rm -rf "$x"
done
B=props/farmhouse,props/church,props/house_med,props/barn,props/factory,props/fuel_station,props/customs_booth,props/windmill
for h in 22; do
	f=$O/bauten_h${h}.png
	[ -s "$f" ] && { echo "skip bauten $h"; continue; }
	x=$S/xdg/veg_b$h
	rm -rf "$x"; mkdir -p "$x"
	(cd $WT && XDG_DATA_HOME=$x nice -n 10 tools/models/prop_scene.sh "$f" --mode=dist --look=race --hour=$h --preset=medium \
		--sprite --dist=30,80,200 --x=14 --models=$B > "$O/bauten_h${h}.log" 2>&1)
	echo "$(date -u +%H:%M:%S) veg bauten $h exit=$?"
	rm -rf "$x"
done
