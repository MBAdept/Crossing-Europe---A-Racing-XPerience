#!/bin/bash
# QA-M2-BILD: three 15-s A/B clips with tools/ab_clip.sh (Arcade left, Modern right, HUD, 60 fps fixed), M2 tree.
# Keeps the Movie Maker AVIs (frames are extracted afterwards). Idempotent (an existing mp4 is skipped).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-M2-BILD
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-3
O=$S/clips
mkdir -p $O $S/tmp
export TMPDIR=$S/tmp
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
clip() {   # clip <name> <gfx> <args...>
	local name=$1 gfx=$2
	shift 2
	if [ -s "$O/$name.mp4" ]; then echo "skip clip $name"; return; fi
	local t0=$SECONDS
	(cd $WT && CLIP_S=15 GFX_ARGS="$gfx" nice -n 10 tools/ab_clip.sh "$O/$name.mp4" "$@" > "$O/$name.log" 2>&1)
	echo "$(date -u +%H:%M:%S) clip $name exit=$? $((SECONDS - t0)) s"
}
# 1 the start at km 0 with countdown, traffic (medium = the default of a PC)
clip start_kh_mittel "--gfx-preset=medium" --stage=kiel_hamburg --from=kiel --hour=12 --weather=normal --vehicle=limousine \
	--seed=11 --autopilot --autopilot-refuel=never --traffic-warmup
# 2 night with traffic, tunnel, bends (DEV km 48, 21 Uhr) – lamps, LOD swaps in motion
clip dev_nacht_mittel "--gfx-preset=medium" --stage=dev_testetappe --start-km=48 --hour=21 --weather=normal --vehicle=limousine \
	--seed=17 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=100
# 3 (only with time left: touch logs/clip3) mountain bends with trees (T4 area, high) – vegetation LOD swaps
if [ -f $S/logs/clip3 ]; then
clip berg_kurven_hoch "--gfx-preset=high" --stage=saragossa_pau --from=saragossa --start-km=196.5 --hour=11 --weather=normal \
	--vehicle=kompakt --seed=4 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=80
fi
