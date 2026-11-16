#!/bin/bash
# Fetches Mesa's radeonsi / llvmpipe capability sources (public, read-only) to see GL_MAX_UNIFORM_BLOCK_SIZE.
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-NACHSTELLEN/godot_src
cd "$D" || exit 1
for f in src/gallium/drivers/radeonsi/si_get.c; do
	out="mesa__$(basename $f)"
	code=$(curl -sS -m 40 -o "$out" -w "%{http_code}" "https://raw.githubusercontent.com/Mesa3D/mesa/main/$f")
	echo "$f $code $(wc -c < "$out")"
done
