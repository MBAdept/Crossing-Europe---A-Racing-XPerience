#!/usr/bin/env bash
# FIX-WASSER queue 2: waits for modern-make, then the two headless scans and the (a) pictures night/deck/cover
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-1 || exit 1
until grep -q '^exit' "$S/golden_make.log"; do sleep 5; done
echo "== scans $(date -u +%T)"
export XDG_DATA_HOME=$S/xdg
nice -n 10 timeout 900 godot --headless --path . -s "$S/scan_bridges.gd" > "$S/scan_bridges2.log" 2>&1
echo "scan_bridges exit $? $(date -u +%T)"
nice -n 10 timeout 900 godot --headless --path . -s "$S/scan_gaps.gd" > "$S/scan_gaps.log" 2>&1
echo "scan_gaps exit $? $(date -u +%T)"
unset XDG_DATA_HOME
export MESA_SHADER_CACHE_DIR=$S/mesa
A=$S/shots
KH="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --start-speed=60 --no-traffic"
T4="--shot-times=0.3,1.5,2.5,4"
echo "== kb_nacht_high $(date -u +%T)"
GFX_ARGS="--gfx-preset=high" nice -n 10 tools/ab_shot.sh "$A/kb_nacht_high" $KH --hour=22 --start-km=77.5 $T4
echo "== kb_tag_deck $(date -u +%T)"
SCREEN=1280x800 GFX_ARGS="--gfx-preset=deck" nice -n 10 tools/ab_shot.sh "$A/kb_tag_deck" $KH --hour=12 --start-km=77.5 $T4
echo "== kb_nacht_deck $(date -u +%T)"
SCREEN=1280x800 GFX_ARGS="--gfx-preset=deck" nice -n 10 tools/ab_shot.sh "$A/kb_nacht_deck" $KH --hour=22 --start-km=77.5 $T4
echo "== kb_cover_deck $(date -u +%T)"
SCREEN=1280x800 GFX_ARGS="--gfx-preset=deck --gfx-debug=cover,far" nice -n 10 tools/ab_shot.sh "$A/kb_cover_deck" $KH --hour=12 --start-km=77.5 $T4
echo "== fertig $(date -u +%T)"
