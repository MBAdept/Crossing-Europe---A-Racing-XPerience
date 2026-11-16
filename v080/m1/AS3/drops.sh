#!/usr/bin/env bash
# AS3 scratch: drops.sh <stage> <from> <km> <set>  (why the props builder leaves a set out near km)
set -uo pipefail
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS3/env.sh
cd "$WT"
nice -n 19 godot --headless --path . -s "$S/drops.gd" -- --stage="$1" --from="$2" --km="$3" --set="$4" 2>&1 \
	| grep -E "DROPS|props/|ERROR|SCRIPT"
