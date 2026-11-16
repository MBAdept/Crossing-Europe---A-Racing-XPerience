#!/bin/bash
# Independent spot check of the golden list: race_s1 and race_n1 rendered by v0.7.0 itself (ref070) and by this tree
# WITHOUT --shot-fast (full render loop, as a player sees it) – compared with tests/golden/arcade_v070.md5.
# Plus Arcade at 1280x800 (Steam Deck window, bars): v0.7.0 vs this tree.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
OUT=$S/golden_spot
mkdir -p "$OUT"
export MESA_SHADER_CACHE_DIR=$S/mesa_golden_spot
LIST=$WT/tests/golden/arcade_v070.md5
one() { # tree dir id times res args...
	local tree=$1 dir=$2 id=$3 times=$4 res=$5; shift 5
	local x=$S/xdg_gs_$tree; rm -rf "$x"; mkdir -p "$x"
	XDG_DATA_HOME=$x nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 ${res}x24" godot --path "$dir" --rendering-driver opengl3 \
		--audio-driver Dummy --resolution "$res" --fixed-fps 60 res://scenes/race/race.tscn -- --screenshot="$OUT/${tree}_${id}_${res}" \
		--shot-times="$times" "$@" > "$OUT/${tree}_${id}_${res}.log" 2>&1
	echo "$tree $id $res exit=$?"
}
S1="--stage=kiel_hamburg --from=kiel --start-km=2 --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --traffic-warmup"
N1="--stage=hamburg_hannover --from=hamburg --start-km=71 --hour=22 --weather=snow --vehicle=kompakt --seed=13 --autopilot --traffic-warmup"
# shellcheck disable=SC2086
one ref "$S/ref070" race_s1 2.2 1280x720 $S1
# shellcheck disable=SC2086
one cur "$WT" race_s1 2.2 1280x720 $S1 --graphics=arcade --gfx-sync
# shellcheck disable=SC2086
one cur "$WT" race_n1 4 1280x720 $N1 --graphics=arcade --gfx-sync
# shellcheck disable=SC2086
one ref "$S/ref070" race_s1 2.2 1280x800 $S1
# shellcheck disable=SC2086
one cur "$WT" race_s1 2.2 1280x800 $S1 --graphics=arcade
echo "-- hashes (list | ref | cur):"
echo "race_s1: $(grep race_s1_00.png "$LIST" | cut -c1-32) | $(md5sum < "$OUT/ref_race_s1_1280x720_00.png" | cut -c1-32) | $(md5sum < "$OUT/cur_race_s1_1280x720_00.png" | cut -c1-32)"
echo "race_n1: $(grep race_n1_00.png "$LIST" | cut -c1-32) | - | $(md5sum < "$OUT/cur_race_n1_1280x720_00.png" | cut -c1-32)"
echo "1280x800 race_s1: ref $(md5sum < "$OUT/ref_race_s1_1280x800_00.png" | cut -c1-32) cur $(md5sum < "$OUT/cur_race_s1_1280x800_00.png" | cut -c1-32)"
echo ALLDONE
