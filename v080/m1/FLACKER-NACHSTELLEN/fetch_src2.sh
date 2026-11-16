#!/bin/bash
# Fetches more reference sources of the Godot engine (public, read-only): the instance uniform helper.
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-NACHSTELLEN/godot_src
cd "$D" || exit 1
BASE=https://raw.githubusercontent.com/godotengine/godot
ref=4.7.2-stable
for f in "$@"; do
	out="${ref}__$(basename $f)"
	code=$(curl -sS -m 60 -o "$out" -w "%{http_code}" "$BASE/$ref/$f")
	echo "$ref $f $code $(wc -c < "$out")"
done
