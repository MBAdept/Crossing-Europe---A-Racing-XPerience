#!/bin/bash
# Fetches reference sources of the Godot engine (public, read-only) for the analysis of the instance-uniform path.
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-NACHSTELLEN/godot_src
cd "$D" || exit 1
BASE=https://raw.githubusercontent.com/godotengine/godot
for ref in "$@"; do
	for f in drivers/gles3/storage/material_storage.cpp drivers/gles3/storage/material_storage.h drivers/gles3/rasterizer_scene_gles3.cpp drivers/gles3/shaders/scene.glsl servers/rendering/renderer_scene_cull.cpp drivers/gles3/storage/config.cpp; do
		out="${ref}__$(basename $f)"
		code=$(curl -sS -m 60 -o "$out" -w "%{http_code}" "$BASE/$ref/$f")
		echo "$ref $f $code $(wc -c < "$out")"
	done
done
