#!/bin/bash
# Frozen-file check of contract §2 Rule 1 against main (v0.7.0). Read-only.
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-4 || exit 2
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
echo "== git diff --stat main HEAD -- <frozen> =="
git diff --stat main HEAD -- "${FROZEN[@]}"
echo "exit=$?"
echo "== name-status (incl. added files) =="
git diff --name-status main HEAD -- "${FROZEN[@]}" | head -50
echo "count=$(git diff --name-status main HEAD -- "${FROZEN[@]}" | wc -l)"
echo "== existence =="
for f in "${FROZEN[@]}"; do test -e "$f" || echo "MISSING $f"; done
echo "== working tree vs HEAD on frozen =="
git status --porcelain -- "${FROZEN[@]}" | head
echo "== .uid/.import files next to frozen scripts (added?) =="
git diff --name-status main HEAD -- 'scripts/race/*.uid' 'scripts/audio/*.uid' | head
echo "== all files changed vs main under scripts/race (non-frozen expected) =="
git diff --name-status main HEAD -- scripts/race/ scripts/audio/ | head -40
echo done
