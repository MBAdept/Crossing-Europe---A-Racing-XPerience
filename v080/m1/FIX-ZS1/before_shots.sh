#!/usr/bin/env bash
# FIX-ZS1: the "before" pictures – the five game files of the fix are set back to the base 92ece73 for one A/B run of
# the standing start (same arguments and shot times as ab_start.sh), then restored from HEAD. Run only while nothing
# else uses the working copy.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-ZS1
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9559b070-4dd-1
FILES="scripts/race3d/road_path.gd scripts/race3d/chunk_context.gd scripts/race3d/chunk_streamer.gd scripts/race3d/layers/vehicles.gd scripts/race3d/builders/gantry.gd"
# shellcheck disable=SC2086
git checkout 92ece73fc8bca9782a1e72f3f71b007ed96641f7 -- $FILES
mkdir -p "$S/before"
bash "$S/ab_start.sh" "$S/before/kh0"
# shellcheck disable=SC2086
git checkout HEAD -- $FILES
git status --short
echo "restored"
