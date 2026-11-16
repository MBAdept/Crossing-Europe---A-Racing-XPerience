#!/usr/bin/env bash
# M2INT: tools/ab_sheet.sh for the reference positions of the brief (S1–S5, T1, T4, C1, N1, N2) and the presets
# "high" + "auto" (this machine's own), plus the player cars kombi / sportwagen / gran_turismo at S1 (high).
# usage: absheet.sh <out_dir> [positions...]   (PRESETS env passes through; CARS=0 skips the cars)
# WT may point at a snapshot copy of the worktree (renders then do not see edits made meanwhile)
WT=${WT:-/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-1}
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/M2INT
LEAD=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead
OUT=$1
shift
POS=("$@")
[ ${#POS[@]} -eq 0 ] && POS=(S1 S2 S3 S4 S5 T1 T4 C1 N1 N2)
NICE=19
[ -f "$LEAD/ZS1_FERTIG" ] && NICE=10
export MESA_SHADER_CACHE_DIR=$S/mesa_cache
mkdir -p "$OUT" "$MESA_SHADER_CACHE_DIR"
cd "$WT" || exit 1
t0=$(date +%s)
PRESETS=${PRESETS:-high auto} nice -n $NICE tools/ab_sheet.sh "$OUT" "${POS[@]}" > "$OUT/ab_sheet.log" 2>&1
echo "ab_sheet exit $? ($(( $(date +%s) - t0 )) s)"
if [ "${CARS:-1}" = 1 ]; then
	for car in kombi sportwagen gran_turismo; do
		t1=$(date +%s)
		GFX_ARGS="--gfx-preset=high" nice -n $NICE tools/ab_shot.sh "$OUT/S1_auto_$car" S1 --vehicle=$car --shot-times=3 \
			> "$OUT/S1_auto_$car.log" 2>&1
		echo "S1 $car exit $? ($(( $(date +%s) - t1 )) s)"
	done
fi
tail -3 "$OUT/index.txt" 2>/dev/null
