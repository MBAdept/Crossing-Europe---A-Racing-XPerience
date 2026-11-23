#!/bin/bash
# tri.sh <out_prefix> <preset> <race args...>: Arcade (R7c tree, --shot-fast) | Modern base 9b02f05 | [Modern 43a1fcc =
# base + AS5aR2 models, before R7c's own commits, when MERGE=1] | Modern R7c of the same simulation state (same args, seed,
# --gfx-sync), side by side with labels: <out>_tri_NN.jpg
# SCREEN env (default 1280x720). Skips a run whose pictures exist already (restart-safe).
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/sh/common.sh
OUT=$1
Q=$2
shift 2
SCREEN=${SCREEN:-1280x720}
MERGE=${MERGE:-0}
# time budget (QA-R7c): combos in tri_skip.txt are skipped, the 43a1fcc run only for combos in tri_merge.txt
COMBO=$(basename "$OUT")
if grep -qx "$COMBO" "$S/sh/tri_skip.txt" 2>/dev/null; then
	echo "$(date -u +%H:%M:%S) $COMBO skipped (time budget)" >> "$S/logs/tri.out"
	exit 0
fi
grep -qx "$COMBO" "$S/sh/tri_merge.txt" 2>/dev/null || MERGE=0
mkdir -p "$(dirname "$OUT")"
run() {   # run <tag> <tree> <mode> <extra...>
	local tag=$1 tree=$2 mode=$3
	shift 3
	if ls "${OUT}_${tag}"_[0-9][0-9].png > /dev/null 2>&1; then
		return 0
	fi
	memwait
	local t0=$SECONDS
	local x=$S/xdg_tri_$tag
	rm -rf "$x"
	mkdir -p "$x"
	(cd "$tree" && XDG_DATA_HOME=$x nice -n 10 timeout 1800 xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . \
		--rendering-driver opengl3 --audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 res://scenes/race/race.tscn -- \
		"--screenshot=${OUT}_${tag}" "$@" "--graphics=$mode" --gfx-sync > "${OUT}_${tag}.log" 2>&1)
	local code=$?
	local errs
	errs=$(grep -cE "SCRIPT ERROR|Parse Error|SHADER ERROR|Shader compilation failed|Too many instances|Modus Modern nicht" "${OUT}_${tag}.log")
	echo "$(date -u +%H:%M:%S) $(basename "$OUT") $tag exit=$code err=$errs $((SECONDS - t0)) s" | tee -a "$S/logs/tri.out"
}
run arcade "$WT" arcade "$@" --shot-fast
run base "$BASE" modern "$@" "--gfx-preset=$Q"
[ "$MERGE" = "1" ] && run merge "$S/merge" modern "$@" "--gfx-preset=$Q"
run r7c "$WT" modern "$@" "--gfx-preset=$Q"
lab() {   # lab <png> <label>
	echo "( $1 -background #10182c -fill white -pointsize 24 -gravity North -splice 0x36 -annotate +0+5 $2 )"
}
for a in "${OUT}"_arcade_[0-9][0-9].png; do
	[ -s "$a" ] || continue
	nn=${a##*_}
	nn=${nn%.png}
	b="${OUT}_base_${nn}.png"
	g="${OUT}_merge_${nn}.png"
	m="${OUT}_r7c_${nn}.png"
	[ -s "$b" ] && [ -s "$m" ] || continue
	if [ "$MERGE" = "1" ] && [ -s "$g" ]; then
		convert \( "$a" -background '#10182c' -fill white -pointsize 24 -gravity North -splice 0x36 -annotate +0+5 "Arcade" \) \
			\( "$b" -background '#10182c' -fill white -pointsize 24 -gravity North -splice 0x36 -annotate +0+5 "Basis 9b02f05 ($Q)" \) \
			\( "$g" -background '#10182c' -fill white -pointsize 24 -gravity North -splice 0x36 -annotate +0+5 "43a1fcc = Basis+AS5aR2 ($Q)" \) \
			\( "$m" -background '#10182c' -fill white -pointsize 24 -gravity North -splice 0x36 -annotate +0+5 "R7c bd1803b ($Q)" \) \
			-background '#10182c' +smush 6 -resize 2560x -quality 88 "${OUT}_tri_${nn}.jpg"
	else
		convert \( "$a" -background '#10182c' -fill white -pointsize 24 -gravity North -splice 0x36 -annotate +0+5 "Arcade" \) \
			\( "$b" -background '#10182c' -fill white -pointsize 24 -gravity North -splice 0x36 -annotate +0+5 "Basis 9b02f05 ($Q)" \) \
			\( "$m" -background '#10182c' -fill white -pointsize 24 -gravity North -splice 0x36 -annotate +0+5 "R7c bd1803b ($Q)" \) \
			-background '#10182c' +smush 6 -resize 2400x -quality 88 "${OUT}_tri_${nn}.jpg"
	fi
done
