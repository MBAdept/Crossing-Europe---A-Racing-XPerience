#!/bin/bash
# AU-R4: Rule 1 – the frozen Arcade paths unchanged against v0.7.0; and the files this package changed against its base.
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_15398915-ab3-4
cd "$W" || exit 1
FROZEN="scripts/race/road_renderer.gd scripts/race/backdrop.gd scripts/race/geo_batch.gd scripts/race/sign_painter.gd
scripts/race/box_vehicle.gd scripts/race/vehicle_pose.gd scripts/race/palette.gd scripts/race/projection.gd
scripts/race/track.gd scripts/race/track_segment.gd scripts/race/session_rules.gd scripts/race/autopilot.gd
scripts/race/tutorial_coach.gd scripts/gameplay scripts/data scripts/audio/engine_audio.gd scripts/audio/engine_bank.gd
scripts/audio/engine_gearbox.gd scripts/audio/room_audio.gd scripts/audio/sfx_synth.gd scripts/audio/traffic_audio.gd
assets/sprites assets/audio/engines assets/audio/traffic assets/audio/music tools/audio/engine_synth.py
tools/audio/traffic_synth.py tools/audio/music_synth.py data"
n=$(git diff --name-only v0.7.0..HEAD -- $FROZEN | wc -l)
echo "Regel 1: Dateien in eingefrorenen Pfaden v0.7.0..HEAD geändert: $n"
git diff --name-only v0.7.0..HEAD -- $FROZEN | head
n2=$(git status --porcelain -- $FROZEN | wc -l)
echo "Regel 1: ungesicherte Änderungen in eingefrorenen Pfaden: $n2"
echo "Dateien dieses Pakets (b6339ad..HEAD und Arbeitsbaum):"
git diff --name-only b6339ad4fe5d26c14e5ad4912848f32f8eb7cd5e -- . | sort
