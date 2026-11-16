#!/bin/bash
# Cheap identity checks (git only)
cd /home/user/crossing-europe---a-racing-xperience
OBJ=b6339ad4fe5d26c14e5ad4912848f32f8eb7cd5e
C1=4209268f0bad80beb9abc2609d92a74cd7279db1
echo "== tag v0.7.0: $(git rev-parse v0.7.0 2>&1)"
echo "== frozen Arcade paths v0.7.0..OBJ (Rule 1) =="
git diff --stat v0.7.0..$OBJ -- \
  scripts/race/road_renderer.gd scripts/race/backdrop.gd scripts/race/geo_batch.gd scripts/race/sign_painter.gd \
  scripts/race/box_vehicle.gd scripts/race/vehicle_pose.gd scripts/race/palette.gd scripts/race/projection.gd \
  scripts/race/track.gd scripts/race/track_segment.gd scripts/race/session_rules.gd scripts/race/autopilot.gd \
  scripts/race/tutorial_coach.gd scripts/gameplay scripts/data \
  scripts/audio/engine_audio.gd scripts/audio/engine_bank.gd scripts/audio/engine_gearbox.gd scripts/audio/room_audio.gd \
  scripts/audio/sfx_synth.gd scripts/audio/traffic_audio.gd \
  assets/sprites assets/audio/engines assets/audio/traffic assets/audio/music \
  tools/audio/engine_synth.py tools/audio/traffic_synth.py tools/audio/music_synth.py data | tail -3
echo "(empty above = no change)"
echo "== files changed C1..OBJ outside the AU area =="
git diff --name-only $C1..$OBJ | grep -vE '^(scripts/audio/modern/|assets/audio/modern/|tools/audio/modern/|tests/unit/audio_modern/|docs/audio-modern.md|config/game_config.json|tools/audio/music/(music_lib.py|mischung.json)|tools/audio/qc/audio_qc.py)'
echo "(empty above = only AU area)"
echo "== engine v3 and music files C1..OBJ =="
git diff --stat $C1..$OBJ -- assets/audio/modern/engines assets/audio/modern/music assets/audio/music assets/audio/modern/ambience assets/audio/modern/ui assets/audio/modern/traffic tools/audio/modern/engine_synth3.py | tail -3
echo "(empty above = byte-identical)"
echo "== audio_manager.gd and scripts/ui C1..OBJ =="
git diff --stat $C1..$OBJ -- scripts/audio/audio_manager.gd scripts/ui scripts/race scripts/core | tail -3
echo "== config: keys outside audio changed? =="
git show $C1:config/game_config.json > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R2-CODE/cfg_c1.json
git show $OBJ:config/game_config.json > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R2-CODE/cfg_r3.json
git show $C1:tools/audio/music/mischung.json > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R2-CODE/mischung_c1.json
git show $OBJ:tools/audio/music/mischung.json > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R2-CODE/mischung_r3.json
echo "== commits on main/v0.8.0 since OBJ base? =="
git merge-base --is-ancestor $C1 $OBJ && echo "C1 is ancestor of OBJ"
git log --oneline -1 origin/wip/v080-au-r3
