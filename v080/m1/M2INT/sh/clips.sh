#!/usr/bin/env bash
# M2INT: the two 30-s A/B clips with the HUD (tools/ab_clip.sh, Modern "Hoch"): which = start | land | both
# WT may point at a snapshot copy of the worktree (the recording then does not see edits made meanwhile)
WT=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-1}
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/M2INT
DL=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/M2INT
LEAD=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead
NICE=19
[ -f "$LEAD/ZS1_FERTIG" ] && NICE=10
export MESA_SHADER_CACHE_DIR=$S/mesa_cache
mkdir -p "$DL/clips" "$S/logs"
cd "$WT" || exit 1
which=${1:-both}
if [ "$which" = start ] || [ "$which" = both ]; then
	t0=$(date +%s)
	GFX_ARGS="--gfx-preset=high" nice -n $NICE tools/ab_clip.sh "$DL/clips/kiel_hamburg_start_tag.mp4" --stage=kiel_hamburg \
		--from=kiel --hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never \
		--traffic-warmup > "$S/logs/clip_start.log" 2>&1
	echo "clip start exit $? ($(( $(date +%s) - t0 )) s)"
fi
if [ "$which" = land ] || [ "$which" = both ]; then
	t0=$(date +%s)
	GFX_ARGS="--gfx-preset=high" nice -n $NICE tools/ab_clip.sh "$DL/clips/dortmund_frankfurt_km121_wald_doerfer.mp4" \
		--stage=dortmund_frankfurt --from=dortmund --start-km=121 --hour=15 --weather=normal --vehicle=gran_turismo --seed=14 \
		--autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --start-speed=110 > "$S/logs/clip_land.log" 2>&1
	echo "clip land exit $? ($(( $(date +%s) - t0 )) s)"
fi
