#!/bin/bash
# QA1: S5 again with the shot at 1.5 s (at 3 s the finish line is already passed), both presets, into the same folder;
# then the overview sheets again from all pictures (ONLY_MONTAGE); then two extra pictures in the Steam Deck window
# (1280x800, preset deck): S1 and S4.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-5
OUT=$S/m1/QA1/ab
export MESA_SHADER_CACHE_DIR=$S/m1/QA1/mesa_ab
export TMPDIR=$S/m1/QA1/tmp
mkdir -p "$TMPDIR"
cd "$WT" || exit 1
t0=$SECONDS
PRESETS="high auto" SHOT_TIMES=1.5 tools/ab_sheet.sh "$OUT" S5 > "$OUT/s5_rerun.log" 2>&1
echo "s5 exit=$? $((SECONDS - t0)) s"
ONLY_MONTAGE=1 PRESETS="high auto" tools/ab_sheet.sh "$OUT" >> "$OUT/s5_rerun.log" 2>&1
echo "montage exit=$?"
tail -5 "$OUT/s5_rerun.log"
mkdir -p "$S/m1/QA1/ab_deck"
for p in S1 S4; do
	t0=$SECONDS
	SCREEN=1280x800 GFX_ARGS="--gfx-preset=deck" tools/ab_shot.sh "$S/m1/QA1/ab_deck/${p}_deck_1280x800" "$p" --shot-times=3 \
		> "$S/m1/QA1/ab_deck/${p}.tool.log" 2>&1
	echo "deck $p exit=$? $((SECONDS - t0)) s"
done
echo ALLDONE
