#!/bin/bash
# QA-BILD fast A/B: like tools/ab_shot.sh, but Modern also runs with --shot-fast and a lead of LEAD s (default 1.0):
# the race runs every frame, the picture is only drawn from LEAD s before each shot (M1 has no particles or other
# GPU-side temporal state; verified against a full run at S2). Usage: abf.sh <outprefix> <race args...>
# Env: GFX_ARGS (Modern only), LEAD, MODES (default "arcade modern"), SCREEN (default 1280x720)
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-2
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-BILD
OUT=$1; shift
LEAD=${LEAD:-1.0}
SCREEN=${SCREEN:-1280x720}
export MESA_SHADER_CACHE_DIR=$S/mesa_ab
export LP_NUM_THREADS=${LP_NUM_THREADS:-2}
mkdir -p "$(dirname "$OUT")"
HAS_TIMES=0
for a in "$@"; do case "$a" in --shot-times=*) HAS_TIMES=1 ;; esac; done
EXTRA=()
[ $HAS_TIMES -eq 0 ] && EXTRA=(--shot-times=2)
cd "$WT" || exit 1
for mode in ${MODES:-arcade modern}; do
	X=$S/xdg_abf_$mode
	rm -rf "$X"; mkdir -p "$X"
	rm -f "${OUT}_${mode}"_[0-9][0-9].png
	MARGS=()
	[ "$mode" = modern ] && MARGS=(--shot-fast-lead=$LEAD ${GFX_ARGS:-})
	t0=$SECONDS
	XDG_DATA_HOME=$X nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . --rendering-driver ${DRIVER:-opengl3} \
		--audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 res://scenes/race/race.tscn -- "--screenshot=${OUT}_${mode}" \
		"$@" "${EXTRA[@]}" --graphics=$mode --gfx-sync --shot-fast --no-chooser "${MARGS[@]}" > "${OUT}_${mode}.log" 2>&1
	code=$?
	n=$(ls "${OUT}_${mode}"_[0-9][0-9].png 2>/dev/null | wc -l)
	echo "  $mode exit=$code pictures=$n $((SECONDS - t0)) s"
	grep -E "SCRIPT ERROR|SHADER ERROR|Too many instances|Modus Modern nicht|ERROR:" "${OUT}_${mode}.log" | head -3
done
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
CAP="$*  |  Modern: ${GFX_ARGS:-}"
for a in "${OUT}"_arcade_[0-9][0-9].png; do
	[ -s "$a" ] || continue
	nn=${a##*_}; nn=${nn%.png}
	m="${OUT}_modern_${nn}.png"
	[ -s "$m" ] || continue
	w=$(identify -format '%w' "$a")
	convert \( "$a" -background '#10182c' -fill white -font $FONT -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Arcade" \) \
		\( "$m" -background '#10182c' -fill white -font $FONT -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Modern" \) \
		-background '#10182c' -gravity North +smush 6 -gravity South -splice 0x34 -fill '#c8d2e6' -font $FONT -pointsize 15 \
		-annotate +0+9 "$(printf '%s' "$CAP" | cut -c1-$((w / 5)))  ·  Bild $nn" -quality 90 "${OUT}_ab_${nn}.jpg"
done
