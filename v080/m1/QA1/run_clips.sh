#!/bin/bash
# QA1: three A/B clips of 30 s (tools/ab_clip.sh), Modern with --gfx-preset=high.
# usage: run_clips.sh [start|nacht|regen ...]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-5
OUT=$S/m1/QA1/clips
mkdir -p "$OUT"
export MESA_SHADER_CACHE_DIR=$S/m1/QA1/mesa_clips
mkdir -p "$MESA_SHADER_CACHE_DIR"
export GFX_ARGS="--gfx-preset=high"
cd "$WT" || exit 1
WHICH=${*:-start nacht regen}
for c in $WHICH; do
	t0=$SECONDS
	case $c in
	start) tools/ab_clip.sh "$OUT/kiel_hamburg_start_tag.mp4" --stage=kiel_hamburg --from=kiel --hour=12 --weather=normal \
		--vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup > "$OUT/start.tool.log" 2>&1 ;;
	nacht) tools/ab_clip.sh "$OUT/dev_km48_nacht_21uhr.mp4" --stage=dev_testetappe --start-km=48 --hour=21 --weather=normal \
		--vehicle=limousine --seed=17 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=100 \
		> "$OUT/nacht.tool.log" 2>&1 ;;
	regen) tools/ab_clip.sh "$OUT/n2_dortmund_frankfurt_regen.mp4" --stage=dortmund_frankfurt --from=dortmund --start-km=121 \
		--hour=16 --weather=rain --vehicle=gran_turismo --seed=14 --autopilot --autopilot-refuel=never --traffic-warmup \
		--no-countdown --start-speed=110 > "$OUT/regen.tool.log" 2>&1 ;;
	esac
	echo "$c exit=$? $((SECONDS - t0)) s"
	tail -6 "$OUT/$c.tool.log"
done
echo ALLDONE
