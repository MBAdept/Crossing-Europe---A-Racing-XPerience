#!/bin/bash
# KRITIK-R3: identity checks on f253687 (git only)
cd /home/user/crossing-europe---a-racing-xperience
OBJ=f2536878c0f426e44caeb522a94ceb3adf234955
BASE=b6339ad4fe5d26c14e5ad4912848f32f8eb7cd5e
C1=4209268f0bad80beb9abc2609d92a74cd7279db1
FROZEN="scripts/race/road_renderer.gd scripts/race/backdrop.gd scripts/race/geo_batch.gd scripts/race/sign_painter.gd
scripts/race/box_vehicle.gd scripts/race/vehicle_pose.gd scripts/race/palette.gd scripts/race/projection.gd
scripts/race/track.gd scripts/race/track_segment.gd scripts/race/session_rules.gd scripts/race/autopilot.gd
scripts/race/tutorial_coach.gd scripts/gameplay scripts/data scripts/audio/engine_audio.gd scripts/audio/engine_bank.gd
scripts/audio/engine_gearbox.gd scripts/audio/room_audio.gd scripts/audio/sfx_synth.gd scripts/audio/traffic_audio.gd
assets/sprites assets/audio/engines assets/audio/traffic assets/audio/music tools/audio/engine_synth.py
tools/audio/traffic_synth.py tools/audio/music_synth.py data"
echo "== v0.7.0 = $(git rev-parse v0.7.0)"
echo "== Rule 1: files in frozen paths changed v0.7.0..OBJ: $(git diff --name-only v0.7.0..$OBJ -- $FROZEN | wc -l)"
git diff --name-only v0.7.0..$OBJ -- $FROZEN | head
echo "== files changed BASE..OBJ:"
git diff --name-only $BASE..$OBJ
echo "== engine v3, music, ambience, ui, traffic (modern) and Arcade music: C1..OBJ changed files: $(git diff --name-only $C1..$OBJ -- assets/audio/modern/engines assets/audio/modern/music assets/audio/music assets/audio/modern/ambience assets/audio/modern/ui assets/audio/modern/traffic tools/audio/modern/engine_synth3.py tools/audio/music | wc -l)"
git diff --name-only $C1..$OBJ -- assets/audio/modern/engines assets/audio/modern/music assets/audio/music assets/audio/modern/ambience assets/audio/modern/ui assets/audio/modern/traffic tools/audio/modern/engine_synth3.py tools/audio/music
echo "== any asset/audio file BASE..OBJ: $(git diff --name-only $BASE..$OBJ -- assets | wc -l)"
echo "== engine/music scripts C1..OBJ:"
git diff --stat $C1..$OBJ -- scripts/audio/modern/engine_audio3.gd scripts/audio/modern/music_director.gd scripts/audio/audio_manager.gd 2>/dev/null | tail -3
ls scripts/audio/modern/ | head -40
echo "== ancestry"
git merge-base --is-ancestor $C1 $OBJ && echo "C1 ancestor of OBJ"
git merge-base --is-ancestor $BASE $OBJ && echo "BASE ancestor of OBJ"
git rev-parse origin/wip/v080-au-r4
