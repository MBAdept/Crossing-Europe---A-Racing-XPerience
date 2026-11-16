#!/usr/bin/env bash
# R3 scratch: A/B picture of a still scene with placed vehicles (probe/inject_ab.gd), Arcade | Modern.
#   ab_inject.sh <out_prefix> <cars.json> <caption> [inject_ab args: --stage= --from= --km= --hour= --weather= --vehicle=]
# GFX_ARGS = extra args of the Modern run (default --gfx-preset=medium).
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
for mode in arcade modern; do
	X=$S/xdg_inject_$mode
	rm -rf "$X"
	mkdir -p "$X"
	extra=""
	[ "$mode" = modern ] && extra="$GFX"
	# shellcheck disable=SC2086
	XDG_DATA_HOME="$X" nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -s "$S/probe/inject_ab.gd" -- --mode=$mode \
		"--out=${OUT}_$mode.png" "--cars=$CARS" "$@" --gfx-sync $extra >"${OUT}_$mode.log" 2>&1
	grep -E "gespeichert|SCRIPT ERROR|Parse Error|SHADER ERROR" "${OUT}_$mode.log" | head -4
done
FONT=(-font DejaVu-Sans-Bold)
convert \( "${OUT}_arcade.png" -background '#10182c' -fill white "${FONT[@]}" -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Arcade" \) \
	\( "${OUT}_modern.png" -background '#10182c' -fill white "${FONT[@]}" -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Modern" \) \
	-background '#10182c' -gravity North +smush 6 -gravity South -splice 0x34 -fill '#c8d2e6' "${FONT[@]}" -pointsize 15 \
	-annotate +0+9 "$CAP" -quality 90 "${OUT}_ab.jpg"
echo "${OUT}_ab.jpg"
