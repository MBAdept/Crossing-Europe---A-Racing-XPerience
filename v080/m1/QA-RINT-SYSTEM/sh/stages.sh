#!/bin/bash
# Arcade identity (v0.7.0 vs head --graphics=arcade) and Rule 3 (head arcade vs head modern), headless, whole stages.
# Usage: stages.sh <job ...>   job = tree:mode:stage:hour:weather:seed:refuel   tree = v070|head
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-SYSTEM
HEAD=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-3
mkdir -p "$S/out/stages"
for job in "$@"; do
	IFS=: read -r tree mode stage hour weather seed refuel <<<"$job"
	if [ "$tree" = v070 ]; then dir="$S/v070"; else dir="$HEAD"; fi
	name="${tree}_${mode}_${stage}_${hour}_${weather}_${seed}_${refuel}"
	home="$S/xdg/stage_$name"
	extra=""
	case "$refuel" in *+speed) refuel=${refuel%+speed}; extra="--autopilot-speeding" ;; esac
	rm -rf "$home"; mkdir -p "$home"
	echo "$(date +%T) start $name"
	( cd "$dir" && XDG_DATA_HOME="$home" nice -n 15 timeout 3600 godot --headless --path . -s "$S/sh/stage_hash.gd" -- \
		--stage="$stage" --hour="$hour" --weather="$weather" --seed="$seed" --autopilot-refuel="$refuel" \
		--timescale=40 --max-seconds=3300 --graphics="$mode" $extra > "$S/out/stages/$name.log" 2>&1 )
	echo "$(date +%T) end $name rc=$? $(grep -E '^HASHES' "$S/out/stages/$name.log")"
done
