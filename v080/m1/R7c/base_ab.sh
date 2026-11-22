#!/usr/bin/env bash
# R7c: A/B pictures of the BASE (43a1fcc = RINT-M2 + AS5aR2) – my files are checked out from the base for the run and
# put back from HEAD afterwards.  base_ab.sh <outdir> "<name:preset:hour> ..."
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c/env.sh
cd "$WT"
FILES="assets/shaders/modern/baked.gdshader assets/shaders/modern/leaves.gdshader assets/shaders/modern/billboard.gdshader scripts/race3d/builders/props.gd scripts/race3d/prop_library.gd scripts/race3d/modern_materials.gd scripts/race3d/model_factory.gd config/game_config.json"
echo "BASE-CHECKOUT $(date +%H:%M)" >> "$S/STAND.md"
git checkout 43a1fcc -- $FILES
"$S/ab_all.sh" "$@"
git checkout HEAD -- $FILES
sed -i '/^BASE-CHECKOUT/d' "$S/STAND.md"
git status --short | grep -v "^??" | head
