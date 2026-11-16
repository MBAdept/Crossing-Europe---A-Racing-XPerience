#!/bin/bash
# KRITIK-R: byte identity checks (git, read-only) and sha256 of the copies.
MAIN=/home/user/crossing-europe---a-racing-xperience
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R
OLD=4209268f0bad80beb9abc2609d92a74cd7279db1
NEW=3d2e6e128d01e53e30ef5538bd58f42888827cc1
cd "$MAIN"
echo "== engine v3, music, ui, ambience, traffic (modern) changed 4209268..3d2e6e1:"
git diff --name-only $OLD $NEW -- assets/audio/modern/engines assets/audio/modern/music assets/audio/modern/ui \
	assets/audio/modern/ambience assets/audio/modern/traffic | wc -l
echo "== tools/audio/music changed:"
git diff --name-only $OLD $NEW -- tools/audio/music
echo "== Rule 1 frozen paths changed v0.7.0..3d2e6e1:"
git diff --name-only v0.7.0 $NEW -- scripts/race/road_renderer.gd scripts/race/backdrop.gd scripts/race/geo_batch.gd \
	scripts/race/sign_painter.gd scripts/race/box_vehicle.gd scripts/race/vehicle_pose.gd scripts/race/palette.gd \
	scripts/race/projection.gd scripts/race/track.gd scripts/race/track_segment.gd scripts/race/session_rules.gd \
	scripts/race/autopilot.gd scripts/race/tutorial_coach.gd scripts/gameplay scripts/data \
	scripts/audio/engine_audio.gd scripts/audio/engine_bank.gd scripts/audio/engine_gearbox.gd scripts/audio/room_audio.gd \
	scripts/audio/sfx_synth.gd scripts/audio/traffic_audio.gd assets/sprites assets/audio/engines assets/audio/traffic \
	assets/audio/music tools/audio/engine_synth.py tools/audio/traffic_synth.py tools/audio/music_synth.py data | wc -l
echo "== all paths changed 4209268..3d2e6e1 outside the AU-R area:"
git diff --name-only $OLD $NEW | grep -v -E "^(scripts/audio/modern/|assets/audio/modern/(vehicle|sfx)/|tools/audio/modern/|tests/unit/audio_modern/|docs/audio-modern.md|config/game_config.json|tools/audio/music/(music_lib.py|mischung.json)|tools/audio/qc/audio_qc.py)"
echo "== config/game_config.json: changed top-level keys outside audio.modern:"
git show $OLD:config/game_config.json > "$K/res/cfg_old.json"
git show $NEW:config/game_config.json > "$K/res/cfg_new.json"
echo "== sha256 of engine/music files in both copies (equal count):"
( cd "$K/before" && find assets/audio/modern/engines assets/audio/modern/music assets/audio/music -type f -name "*.*" ! -name "*.import" -exec sha256sum {} + | sort ) > "$K/res/sha_before.txt"
( cd "$K/after" && find assets/audio/modern/engines assets/audio/modern/music assets/audio/music -type f -name "*.*" ! -name "*.import" -exec sha256sum {} + | sort ) > "$K/res/sha_after.txt"
wc -l < "$K/res/sha_before.txt"
diff "$K/res/sha_before.txt" "$K/res/sha_after.txt" && echo "engine+music files byte-identical"
echo "== working copy after == AU-R head (tracked files):"
cd "$MAIN/.claude/worktrees/wf_5dca29a9-6fb-1" && git status --porcelain | wc -l && git rev-parse HEAD
