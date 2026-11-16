#!/usr/bin/env bash
# FIX-WASSER: the "before" pictures (Modern only) with layers/far_ground.gd of the base 3a23cb8 set in; restored from
# HEAD at the end (also on an error). Run only while nothing else uses the working copy.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-1
F=scripts/race3d/layers/far_ground.gd
cd "$WT" || exit 1
restore() {
	cd "$WT" && git checkout HEAD -- "$F" && git status --short && echo "restored $(date -u +%T)"
}
trap restore EXIT
git show 3a23cb8dad346b623118fc0bcab9c0ffaea1efbf:$F > "$F"
B=$S/before
mkdir -p "$B"
KH="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --start-speed=60 --no-traffic"
T4="--shot-times=0.3,1.5,2.5,4"
echo "== start $(date -u +%T)"
# the old change detector modern_s4_mittel exactly as tools/golden.sh modern-make draws it (its MD5 must be a55e8fa3…)
X=$(mktemp -d "$S/xdg_s4.XXXXXX")
XDG_DATA_HOME=$X MESA_SHADER_CACHE_DIR=$S/mesa nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . \
	--rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 res://scenes/race/race.tscn -- \
	--screenshot="$B/modern_s4_mittel" --shot-times=3 --stage=kiel_hamburg --from=kiel --start-km=80 --hour=12 --weather=normal \
	--vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=50 \
	--gfx-preset=medium --graphics=modern --gfx-sync --audio-sync > "$B/modern_s4_mittel.log" 2>&1
echo "s4 alt exit $? $(md5sum "$B/modern_s4_mittel_00.png") $(date -u +%T)"
rm -rf "$X"
GFX_ARGS="--gfx-preset=high" bash "$S/modern_only.sh" "$B/kb_tag_high" $KH --hour=12 --start-km=77.5 $T4
GFX_ARGS="--gfx-preset=high" bash "$S/modern_only.sh" "$B/kb_nacht_high" $KH --hour=22 --start-km=77.5 $T4
SCREEN=1280x800 GFX_ARGS="--gfx-preset=deck" bash "$S/modern_only.sh" "$B/kb_tag_deck" $KH --hour=12 --start-km=77.5 $T4
SCREEN=1280x800 GFX_ARGS="--gfx-preset=deck" bash "$S/modern_only.sh" "$B/kb_nacht_deck" $KH --hour=22 --start-km=77.5 $T4
GFX_ARGS="--gfx-preset=high" bash "$S/modern_only.sh" "$B/elb_tag_high" $KH --hour=12 --start-km=84.3 --shot-times=0.3,1.5,2.5
O="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --start-speed=60 --no-traffic --hour=12"
GFX_ARGS="--gfx-preset=high" bash "$S/modern_only.sh" "$B/holtenau" --stage=rostock_kiel --from=rostock $O --start-km=200.0 $T4
GFX_ARGS="--gfx-preset=high" bash "$S/modern_only.sh" "$B/severin" --stage=frankfurt_koeln --from=frankfurt $O --start-km=185.9 $T4
GFX_ARGS="--gfx-preset=high" bash "$S/modern_only.sh" "$B/elisabeth" --stage=budapest_wien --from=wien $O --start-km=241.1 $T4
echo "== fertig $(date -u +%T)"
