#!/bin/bash
# Frozen-file check of contract §2 Rule 1 against main (v0.7.0). Read-only.
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3 || exit 2
FROZEN=(
  scripts/race/road_renderer.gd scripts/race/backdrop.gd scripts/race/geo_batch.gd scripts/race/sign_painter.gd
  scripts/race/box_vehicle.gd scripts/race/vehicle_pose.gd scripts/race/palette.gd scripts/race/projection.gd
  scripts/race/track.gd scripts/race/track_segment.gd scripts/race/session_rules.gd scripts/race/autopilot.gd
  scripts/race/tutorial_coach.gd scripts/gameplay/ scripts/data/
  scripts/audio/engine_audio.gd scripts/audio/engine_bank.gd scripts/audio/engine_gearbox.gd
  scripts/audio/room_audio.gd scripts/audio/sfx_synth.gd scripts/audio/traffic_audio.gd
  assets/sprites/ assets/audio/engines/ assets/audio/traffic/ assets/audio/music/
  tools/audio/engine_synth.py tools/audio/traffic_synth.py tools/audio/music_synth.py data/
)
echo "== git diff --stat main -- <frozen> =="
git diff --stat main -- "${FROZEN[@]}"
echo "exit=$?"
echo "== name-status (incl. added files) =="
git diff --name-status main -- "${FROZEN[@]}" | head -50
echo "== existence =="
for f in "${FROZEN[@]}"; do test -e "$f" || echo "MISSING $f"; done
echo "== working tree vs HEAD on frozen =="
git status --porcelain -- "${FROZEN[@]}" | head
echo done
