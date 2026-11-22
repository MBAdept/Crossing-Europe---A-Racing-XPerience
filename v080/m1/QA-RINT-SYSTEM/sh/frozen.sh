#!/bin/bash
# Diff of the frozen Arcade file list (contract §2 Rule 1) against main and against the base.
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-3 || exit 1
LIST="scripts/race/road_renderer.gd scripts/race/backdrop.gd scripts/race/geo_batch.gd scripts/race/sign_painter.gd scripts/race/box_vehicle.gd scripts/race/vehicle_pose.gd scripts/race/palette.gd scripts/race/projection.gd scripts/race/track.gd scripts/race/track_segment.gd scripts/race/session_rules.gd scripts/race/autopilot.gd scripts/race/tutorial_coach.gd scripts/gameplay scripts/data scripts/audio/engine_audio.gd scripts/audio/engine_bank.gd scripts/audio/engine_gearbox.gd scripts/audio/room_audio.gd scripts/audio/sfx_synth.gd scripts/audio/traffic_audio.gd assets/sprites assets/audio/engines assets/audio/traffic assets/audio/music tools/audio/engine_synth.py tools/audio/traffic_synth.py tools/audio/music_synth.py data"
echo "main = $(git rev-parse --short main)  head = $(git rev-parse --short HEAD)"
echo "--- diff --stat main HEAD -- frozen (empty = unchanged):"
git diff --stat main HEAD -- $LIST
echo "--- working tree vs HEAD for frozen:"
git status --porcelain -- $LIST
echo "head files: $(git ls-files -- $LIST | wc -l)  main files: $(git ls-tree -r --name-only main -- $LIST | wc -l)"
for f in $LIST; do [ -e "$f" ] || echo "MISSING $f"; done
echo "--- diff --stat 515dd51 HEAD frozen:"
git diff --stat 515dd51 HEAD -- $LIST
echo done
