#!/usr/bin/env bash
# Integration helper (not part of the repository): cross-package signals on the merged tree, one after the other.
#   1. the sound checks of the audio package, run directly (CHECK lines): headless, headless with playback forced
#      (--live), and under Xvfb with the Dummy audio driver
#   2. the session scenarios of the core package with the Modern sound profile (and with both Modern)
# Usage: combo_checks.sh <project dir> <log dir> <xdg base dir>
set -uo pipefail
PROJ=$1
LOGS=$2
XDG=$3
mkdir -p "$LOGS"
cd "$PROJ"
fresh() { rm -rf "$XDG/$1"; mkdir -p "$XDG/$1"; export XDG_DATA_HOME="$XDG/$1"; }
report() { # <name> <exit code> <seconds>
	echo "== $1: Exit $2, $3 s, CHECK-Zeilen $(grep -c '^CHECK ' "$LOGS/$1.log"), FEHLER $(grep -c '^CHECK.*FEHLER' "$LOGS/$1.log"), Skriptfehler $(grep -c 'SCRIPT ERROR' "$LOGS/$1.log"), ERROR-Zeilen $(grep -c '^ERROR' "$LOGS/$1.log")"
	grep -E '^CHECK' "$LOGS/$1.log" | cut -c1-420
}
headless() { # <name> <script> <args after -->
	local name=$1 script=$2
	shift 2
	fresh "$name"
	local t0=$SECONDS
	nice -n 10 timeout 600 godot --headless --path . -s "res://$script" -- "$@" > "$LOGS/$name.log" 2>&1
	report "$name" $? $((SECONDS - t0))
}
xvfb() { # <name> <script> <args after -->
	local name=$1 script=$2
	shift 2
	fresh "$name"
	local t0=$SECONDS
	nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy \
		--resolution 1280x720 --fixed-fps 60 -s "res://$script" -- "$@" > "$LOGS/$name.log" 2>&1
	report "$name" $? $((SECONDS - t0))
}
headless audio_headless tests/unit/audio_modern/check_modern_audio.gd --graphics=arcade
headless audio_live tests/unit/audio_modern/check_modern_audio.gd --graphics=arcade --live
xvfb audio_xvfb tests/unit/audio_modern/check_modern_audio.gd --graphics=arcade
headless session_arcade_snd_modern tests/race/check_session.gd --graphics=arcade --sound=modern
headless session_modern_snd_modern tests/race/check_session.gd --graphics=modern --sound=modern
headless seam_snd_modern tests/race3d/check_seam.gd --sound=modern
