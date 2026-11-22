#!/bin/bash
# R7a: on the final head (warm-front change): render checks that stream, and two Modern golden frames compared
# pixel by pixel with the ones kept on e81886a (the corridor is order-independent: they must be identical).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1
export TMPDIR=$S/tmp
mkdir -p "$S/rc2" "$S/xdg/rc2" "$S/gold_final"
cd "$WT" || exit 2
echo "$(date -u +%H:%M:%S) start $(git -C "$WT" rev-parse --short HEAD)"
for f in terrain_cover seam_render session_modern start_km0; do
	t0=$SECONDS
	XDG_DATA_HOME=$S/xdg/rc2 nice -n 10 tools/run_render_checks.sh modern "$f" > "$S/rc2/$f.log" 2>&1
	echo "$(date -u +%H:%M:%S) rc $f exit=$? $((SECONDS - t0)) s: $(grep -E 'RENDER-CHECK-DATEI' "$S/rc2/$f.log" | tr -s ' ' | tr '\n' ' ')"
done
for g in modern_start_mittel modern_s4_mittel; do
	t0=$SECONDS
	XDG_DATA_HOME=$S/xdg/rc2 MESA_SHADER_CACHE_DIR=$S/mesa KEEP=$S/gold_final GLES_ID= nice -n 10 tools/golden.sh modern-check "$g" > "$S/gold_final_$g.log" 2>&1
	if cmp -s "$S/gold_final/${g}_00.png" "$S/gold_mine/${g}_00.png"; then same=identisch; else same=ANDERS; fi
	echo "$(date -u +%H:%M:%S) golden $g $((SECONDS - t0)) s: gegen e81886a $same"
done
echo "$(date -u +%H:%M:%S) done"
