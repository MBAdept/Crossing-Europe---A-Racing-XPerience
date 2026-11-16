#!/bin/bash
# QA-M2-BILD: vehicle probe (probe/qa_vehicles.gd) in Arcade, Modern M2 and Modern ZS1 – same view, same test cars.
#   vehicles.sh traffic|player
# Output shots/veh/<tag>_<scene>.png, logs shots/veh/<tag>.log. Idempotent per tag (QA-VEH-END in the log).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
O=$S/shots/veh
mkdir -p $O
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
veh() {   # veh <tree> <mode> <tag> <args...>
	local tree=$1 mode=$2 tag=$3
	shift 3
	local wt=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-3
	[ "$tree" = zs1 ] && wt=$S/zs1tree
	if grep -q "QA-VEH-END" "$O/$tag.log" 2> /dev/null; then echo "skip veh $tag"; return; fi
	local x=$S/xdg/veh_$$
	rm -rf "$x"; mkdir -p "$x"
	local t0=$SECONDS
	(cd "$wt" && XDG_DATA_HOME=$x nice -n 10 timeout 1200 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
		--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s $S/probe/qa_vehicles.gd -- \
		--graphics=$mode --gfx-sync --sound=arcade --out=$O --tag=$tag "$@" > "$O/$tag.log" 2>&1)
	echo "$(date -u +%H:%M:%S) veh $tree $mode $tag exit=$? $((SECONDS - t0)) s pics=$(ls $O/${tag}_*.png 2> /dev/null | wc -l)"
	rm -rf "$x"
}
if [ "${1:-traffic}" = traffic ]; then
	# traffic rows at 20 / 60 / 150 m, night and day (limousine as the player, hidden in the traffic pictures)
	for h in 22 12; do
		veh m2 arcade "arc_h${h}" --hour=$h --only=d20,d60,d150,player
		veh m2 modern "m2_h${h}" --hour=$h --gfx-preset=medium --only=d20,d60,d150,player
		veh zs1 modern "zs1_h${h}" --hour=$h --gfx-preset=medium --only=d20,d60,d150,player
	done
else
	# the lod0 <-> lod1 swap at 40 m of "Mittel" (user report of ZS1: paint of a white car ~40 m ahead flickers)
	veh m2 modern "m2_lod_h12" --hour=12 --gfx-preset=medium --only=d37w,d43w,d37v,d43v
	veh m2 arcade "arc_lod_h12" --hour=12 --only=d37w,d43w,d37v,d43v
	# every player car from behind (chase view, braking) and its own model 30 m ahead at night; by day the two cars
	# whose paint was questioned (sports car, GT) – the others are in the A/B positions by day
	for v in kombi sportwagen gran_turismo kompakt; do
		veh m2 arcade "arc_${v}_h22" --hour=22 --vehicle=$v --only=player,player_nobrake,player30
		veh m2 modern "m2_${v}_h22" --hour=22 --vehicle=$v --gfx-preset=medium --only=player,player_nobrake,player30
	done
	for v in sportwagen gran_turismo; do
		veh m2 arcade "arc_${v}_h12" --hour=12 --vehicle=$v --only=player,player_nobrake,player30
		veh m2 modern "m2_${v}_h12" --hour=12 --vehicle=$v --gfx-preset=medium --only=player,player_nobrake,player30
	done
fi
