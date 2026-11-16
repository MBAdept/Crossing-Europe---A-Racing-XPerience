#!/usr/bin/env bash
# Fetch a few Godot engine source files (read-only reference for the AudioStreamInteractive behaviour).
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-D1/godot_src
mkdir -p "$D"
TAG=${1:-4.7.2-stable}
BASE="https://raw.githubusercontent.com/godotengine/godot/$TAG"
for f in modules/interactive_music/audio_stream_interactive.cpp modules/interactive_music/audio_stream_interactive.h modules/vorbis/audio_stream_ogg_vorbis.cpp; do
	curl -sS -m 60 -o "$D/$(basename $f)" "$BASE/$f"
	echo "$f exit=$? bytes=$(wc -c < "$D/$(basename $f)")"
done
head -3 "$D/audio_stream_interactive.cpp"
