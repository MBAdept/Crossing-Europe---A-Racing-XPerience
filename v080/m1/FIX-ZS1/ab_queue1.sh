#!/usr/bin/env bash
# FIX-ZS1 queue 1: boats (CHECK 3) and three more stage starts, one run after the other
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-ZS1
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9559b070-4dd-1
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p "$S/boats" "$S/starts"
BASE="--hour=12 --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never"
echo "== boote km 78 $(date -u +%T)"
GFX_ARGS="--gfx-preset=high" nice -n 5 tools/ab_shot.sh "$S/boats/kh78" --stage=kiel_hamburg --from=kiel $BASE --no-countdown \
	--start-km=78.0 --start-speed=60 --no-traffic --shot-times=0.3,1.5,2.5
echo "== boote km 83.8 $(date -u +%T)"
GFX_ARGS="--gfx-preset=high" nice -n 5 tools/ab_shot.sh "$S/boats/kh838" --stage=kiel_hamburg --from=kiel $BASE --no-countdown \
	--start-km=83.8 --start-speed=60 --no-traffic --shot-times=0.3,1.5
echo "== start steigung venedig_ljubljana ab ljubljana $(date -u +%T)"
GFX_ARGS="--gfx-preset=medium" nice -n 5 tools/ab_shot.sh "$S/starts/vl" --stage=venedig_ljubljana --from=ljubljana $BASE \
	--traffic-warmup --shot-times=1,3,3.7,4.5,7
echo "== start stadt koeln_bruessel ab koeln $(date -u +%T)"
GFX_ARGS="--gfx-preset=medium" nice -n 5 tools/ab_shot.sh "$S/starts/kb" --stage=koeln_bruessel --from=koeln $BASE \
	--traffic-warmup --shot-times=1,3,3.7,4.5,7
echo "== start nacht saragossa_pau ab pau 22 uhr $(date -u +%T)"
GFX_ARGS="--gfx-preset=medium" nice -n 5 tools/ab_shot.sh "$S/starts/sp22" --stage=saragossa_pau --from=pau $BASE --hour=22 \
	--traffic-warmup --shot-times=1,3,3.7,4.5,7
echo "== fertig $(date -u +%T)"
