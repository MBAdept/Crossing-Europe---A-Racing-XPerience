#!/usr/bin/env bash
# AS3 scratch: census of the sets a stage places between --start and --km (stage_sets.gd)
#   census.sh <stage> <from> <start_km> <end_km>
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3/env.sh
cd "$WT"
nice -n 19 godot --headless --path . -s "$S/stage_sets.gd" -- --stage="$1" --from="$2" --start="$3" --km="$4" --list="${5:-}" 2>&1 \
	| grep -E "STAGE|props/|object:|sections|LISTE" | grep -v "sprite_sets\|fallbacks"
