#!/usr/bin/env bash
# usage: settings_cases.sh  -> runs the cases, prints PROBE/FILE lines
W=$(cd "$(dirname "$0")" && pwd)
case "$W" in /*) ;; *) echo "W not absolute"; exit 9;; esac
APP="godot/app_userdata/Crossing Europe – A Racing Xperience"
run_case() {  # name, settings json ("" = none), marker (0/1), config override json ("" = none), args...
	local name=$1 json=$2 marker=$3 over=$4; shift 4
	local X="$W/xdg_cases/$name"
	rm -rf "$X"; mkdir -p "$X/$APP"
	[ -n "$json" ] && printf '%s' "$json" > "$X/$APP/settings.json"
	[ "$marker" = 1 ] && echo "modern 0.8.0 1" > "$X/$APP/modern_start.lock"
	[ -n "$over" ] && printf '%s' "$over" > "$X/$APP/game_config.json"
	echo "=== $name  args: $*"
	[ -n "$json" ] && echo "IN   $json"
	(cd "$W/tree" && XDG_DATA_HOME="$X" nice -n 10 godot --headless --path . -s res://tests/qa/settings_probe.gd -- "$@" 2>&1) | grep -E "^PROBE|^FILE|^SAVED|^LEVELS|ERROR|WARNING|SCRIPT" | cut -c1-900
	echo "MARKER-AFTER $([ -e "$X/$APP/modern_start.lock" ] && echo yes || echo no)"
}
"$@"
