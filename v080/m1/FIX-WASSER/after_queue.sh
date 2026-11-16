#!/usr/bin/env bash
# FIX-WASSER: the "after" A/B pictures (tools/ab_shot.sh: Arcade | Modern with the fix), one run after the other
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-1 || exit 1
export MESA_SHADER_CACHE_DIR=$S/mesa
A=$S/shots
mkdir -p "$A"
KH="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --start-speed=60 --no-traffic"
T4="--shot-times=0.3,1.5,2.5,4"
O="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --start-speed=60 --no-traffic --hour=12"
ab() {
	local name=$1
	shift
	echo "== $name $(date -u +%T)"
	"$@"
}
echo "== start $(date -u +%T) HEAD $(git rev-parse --short HEAD)"
git status --short
# (in queue2.sh) ab kb_nacht_high env GFX_ARGS="--gfx-preset=high" nice -n 10 tools/ab_shot.sh "$A/kb_nacht_high" $KH --hour=22 --start-km=77.5 $T4
# (in queue2.sh) ab kb_tag_deck env SCREEN=1280x800 GFX_ARGS="--gfx-preset=deck" nice -n 10 tools/ab_shot.sh "$A/kb_tag_deck" $KH --hour=12 --start-km=77.5 $T4
# (in queue2.sh) ab kb_nacht_deck env SCREEN=1280x800 GFX_ARGS="--gfx-preset=deck" nice -n 10 tools/ab_shot.sh "$A/kb_nacht_deck" $KH --hour=22 --start-km=77.5 $T4
ab elb_tag_high env GFX_ARGS="--gfx-preset=high" nice -n 10 tools/ab_shot.sh "$A/elb_tag_high" $KH --hour=12 --start-km=84.3 --shot-times=0.3,1.5,2.5
ab holtenau env GFX_ARGS="--gfx-preset=high" nice -n 10 tools/ab_shot.sh "$A/holtenau" --stage=rostock_kiel --from=rostock $O --start-km=200.0 $T4
ab severin env GFX_ARGS="--gfx-preset=high" nice -n 10 tools/ab_shot.sh "$A/severin" --stage=frankfurt_koeln --from=frankfurt $O --start-km=185.9 $T4
ab elisabeth env GFX_ARGS="--gfx-preset=high" nice -n 10 tools/ab_shot.sh "$A/elisabeth" --stage=budapest_wien --from=wien $O --start-km=241.1 $T4
ab venedig env GFX_ARGS="--gfx-preset=high" nice -n 10 tools/ab_shot.sh "$A/venedig" --stage=mailand_venedig --from=mailand $O --start-km=267.9 $T4
# (in queue2.sh) # where the far ground shows at the bridge (cyan plane, yellow rim, magenta = hole): Steam Deck stage, ribbon 480 m
# (in queue2.sh) ab kb_cover_deck env SCREEN=1280x800 GFX_ARGS="--gfx-preset=deck --gfx-debug=cover,far" nice -n 10 tools/ab_shot.sh "$A/kb_cover_deck" $KH --hour=12 --start-km=77.5 $T4
echo "== fertig $(date -u +%T)"
