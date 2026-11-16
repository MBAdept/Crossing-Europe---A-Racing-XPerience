#!/bin/bash
# Extract read-only copies of selected paths of both builds into the scratch folder (no checkout, no git state change).
set -e
REPO=/home/user/crossing-europe---a-racing-xperience
OUT=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-ANALYSE/src
ZS1=39849f0263921f798da4326b83dff30d83a947d2
M2=6e484056ec87e2fa614061000a362feb2b5a6db8
PATHS="scripts assets/shaders assets/models config docs ARCHITECTURE.md tools/blender/ce3d tools/blender/validate_models.py tools/blender/export_models.py tools/models tests/race3d tests/unit/race3d tests/sim tests/unit/core project.godot data"
cd "$REPO"
for tag in zs1 m2; do
  if [ "$tag" = zs1 ]; then C=$ZS1; else C=$M2; fi
  mkdir -p "$OUT/$tag"
  git archive "$C" $PATHS | tar -x -C "$OUT/$tag"
done
du -sh "$OUT"/*
