#!/usr/bin/env bash
# NACH-R7b: one picture triple of the same simulation state: Arcade | Modern 2c154bc (R7b) | Modern c50d58f (FIX-R7b).
#   abc.sh <out prefix> <preset> <screen> <race args…>
# Head: tools/ab_shot.sh of the worktree (Arcade + Modern); base: the Modern run alone in the base copy.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7b
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-9
B=$S/base
OUT=$1
PRESET=$2
SCREEN=$3
shift 3
export TMPDIR=$S/tmp
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p $TMPDIR $MESA_SHADER_CACHE_DIR "$(dirname "$OUT")"
while [ "$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)" -lt 3000 ]; do sleep 20; done
T0=$SECONDS
if [ -z "${SKIP_HEAD:-}" ]; then
	(cd $W && GFX_ARGS="--gfx-preset=$PRESET ${EXTRA_GFX:-}" SCREEN=$SCREEN nice -n 10 tools/ab_shot.sh "$OUT" "$@" > "${OUT}_ab.log" 2>&1) || echo "HEAD FEHLER $OUT"
fi
if [ -z "${SKIP_BASE:-}" ]; then
	X=$S/xdg_base_run
	rm -rf $X
	mkdir -p $X
	(cd $B && XDG_DATA_HOME=$X nice -n 10 timeout 600 xvfb-run -a -s "-screen 0 ${SCREEN}x24" godot --path . --rendering-driver opengl3 \
		--audio-driver Dummy --resolution "$SCREEN" --fixed-fps 60 res://scenes/race/race.tscn -- "--screenshot=${OUT}_basis" "$@" \
		--graphics=modern --gfx-sync "--gfx-preset=$PRESET" ${EXTRA_GFX:-} > "${OUT}_basis.log" 2>&1) || echo "BASE FEHLER $OUT"
	grep -qE "SCRIPT ERROR|SHADER ERROR|Modus Modern nicht" "${OUT}_basis.log" && echo "BASE LOGFEHLER $OUT"
fi
grep -qE "SCRIPT ERROR|SHADER ERROR" "${OUT}_modern.log" 2>/dev/null && echo "HEAD LOGFEHLER $OUT"
A="${OUT}_arcade_00.png"
M="${OUT}_modern_00.png"
BS="${OUT}_basis_00.png"
if [ -s "$A" ] && [ -s "$M" ] && [ -s "$BS" ]; then
	convert \
		\( "$A" -background '#10182c' -fill white -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Arcade" \) \
		\( "$BS" -background '#10182c' -fill white -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Modern R7b 2c154bc" \) \
		\( "$M" -background '#10182c' -fill white -pointsize 26 -gravity North -splice 0x44 -annotate +0+7 "Modern FIX-R7b c50d58f" \) \
		-background '#10182c' -gravity North +smush 6 \
		-gravity South -splice 0x34 -fill '#c8d2e6' -pointsize 15 -annotate +0+9 "$(echo "$*" | cut -c1-200)  |  $PRESET $SCREEN" \
		-quality 88 "${OUT}_abc.jpg"
fi
echo "$(basename "$OUT") $((SECONDS - T0)) s"
