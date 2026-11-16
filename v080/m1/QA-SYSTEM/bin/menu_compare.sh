#!/bin/bash
# Compares the menu pictures of v0.7.0 (ref) and this tree (cur): identical md5, else differing pixel count and a
# diff picture (red = different) next to both.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
RES=${1:-1280x720}
D=$S/menus/$RES
mkdir -p "$D/diff"
for f in "$D"/ref/*.png; do
	n=$(basename "$f")
	c="$D/cur/$n"
	if [ ! -f "$c" ]; then echo "$n: fehlt in cur"; continue; fi
	if [ "$(md5sum < "$f" | cut -c1-32)" = "$(md5sum < "$c" | cut -c1-32)" ]; then
		echo "$n: identisch"
	else
		ae=$(compare -metric AE "$f" "$c" "$D/diff/$n" 2>&1 | awk '{print $1}')
		echo "$n: ANDERS ($ae Pixel)"
	fi
done
