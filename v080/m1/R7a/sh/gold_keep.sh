#!/bin/bash
# R7a: the Modern golden frames kept as pictures – this tree and the base – to look at what changed (no modern-make).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1
export TMPDIR=$S/tmp
mkdir -p "$S/xdg/gk" "$S/gold_mine" "$S/gold_base"
for w in mine base; do
	T=$WT
	[ "$w" = base ] && T=$S/base
	t0=$SECONDS
	(cd "$T" && XDG_DATA_HOME=$S/xdg/gk MESA_SHADER_CACHE_DIR=$S/mesa KEEP=$S/gold_$w GLES_ID= nice -n 10 tools/golden.sh modern-check > "$S/gold_$w.log" 2>&1)
	echo "$(date -u +%H:%M:%S) gold $w exit=$? $((SECONDS - t0)) s: $(grep -a 'GOLDEN' "$S/gold_$w.log" | tr '\n' ' ')"
done
echo "$(date -u +%H:%M:%S) done"
