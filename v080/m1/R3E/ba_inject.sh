#!/usr/bin/env bash
# R3E scratch: before/after picture of a still scene with placed vehicles, both Modern: R3's painted box | R3E's picture.
#   ba_inject.sh <out_prefix> <cars.json> <caption> [inject_ab args …]
set -uo pipefail
OUT=$1
CARS=$2
CAP=$3
shift 3
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-2
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R3E
cd "$WT"
export MESA_SHADER_CACHE_DIR=$S/mesa
GFX=${GFX_ARGS:---gfx-preset=medium}
for st in 0 1; do
	X=$S/xdg_ba_$st
	rm -rf "$X"
	mkdir -p "$X"
	# shellcheck disable=SC2086
	XDG_DATA_HOME="$X" nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s "$S/probe/inject_ab.gd" -- --mode=modern \
		"--out=${OUT}_st$st.png" "--cars=$CARS" "$@" --standins=$st --gfx-sync $GFX >"${OUT}_st$st.log" 2>&1
	grep -E "gespeichert|SCRIPT ERROR|Parse Error|SHADER ERROR" "${OUT}_st$st.log" | head -4
done
FONT=(-font DejaVu-Sans-Bold)
convert \( "${OUT}_st0.png" -background '#10182c' -fill white "${FONT[@]}" -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Vorher: gemalter Kasten (R3)" \) \
	\( "${OUT}_st1.png" -background '#10182c' -fill white "${FONT[@]}" -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Nachher: Arcades Bild (R3E)" \) \
	-background '#10182c' -gravity North +smush 6 -gravity South -splice 0x34 -fill '#c8d2e6' "${FONT[@]}" -pointsize 15 \
	-annotate +0+9 "$CAP" -quality 90 "${OUT}_ba.jpg"
echo "${OUT}_ba.jpg"
