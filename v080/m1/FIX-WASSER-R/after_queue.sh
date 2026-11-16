#!/usr/bin/env bash
# FIX-WASSER-R: the "after" pictures (Arcade | Modern with tools/ab_shot.sh) of the fixed working copy.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER-R
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-3 || exit 1
export MESA_SHADER_CACHE_DIR=$S/mesa
A=$S/shots
mkdir -p "$A"
echo "== start $(date -u +%T)"
KH="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --traffic-warmup --start-speed=80"
GFX_ARGS="--gfx-preset=high" AB_TIMEOUT=900 tools/ab_shot.sh "$A/kb_nacht_high" $KH --hour=22 --start-km=77.6 --shot-times=0.3,2,4,6
GFX_ARGS="--gfx-preset=high" AB_TIMEOUT=900 tools/ab_shot.sh "$A/kb_tag_high" $KH --hour=12 --start-km=77.6 --shot-times=0.3,2,4,6
SCREEN=1280x800 GFX_ARGS="--gfx-preset=deck" AB_TIMEOUT=900 tools/ab_shot.sh "$A/kb_nacht_deck" $KH --hour=22 --start-km=77.6 --shot-times=0.3,2,4
O="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --no-traffic --hour=12 --start-speed=80"
GFX_ARGS="--gfx-preset=high" AB_TIMEOUT=900 tools/ab_shot.sh "$A/belgrad" --stage=slavonski_brod_belgrad --from=slavonski_brod $O --start-km=198.6 --shot-times=0.3,2,4
GFX_ARGS="--gfx-preset=high" AB_TIMEOUT=900 tools/ab_shot.sh "$A/hannover" --stage=hamburg_hannover --from=hamburg $O --start-km=146.6 --shot-times=0.3,2,4
GFX_ARGS="--gfx-preset=high" AB_TIMEOUT=900 tools/ab_shot.sh "$A/leipzig" --stage=dresden_leipzig --from=dresden $O --start-km=107.6 --shot-times=0.3,2,4
echo "== fertig $(date -u +%T)"
