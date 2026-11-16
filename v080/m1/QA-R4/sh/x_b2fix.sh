#!/bin/bash
# B2 fix prototype in the mutation copy: N2N 22:00 rain, 2 s, then restore road.gdshader
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R4
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-3
F=assets/shaders/modern/road.gdshader
cp $WT/$F $S/mut/$F
python3 $S/sh/b2fix_patch.py $S/mut/$F || exit 2
ARGS=$($S/sh/pos.sh N2N)
mkdir -p $S/shots/mut
cd $S/mut || exit 2
export MESA_SHADER_CACHE_DIR=$S/mesa_mut
export XDG_DATA_HOME=$S/xdg_mut
# shellcheck disable=SC2086
GFX_ARGS="--gfx-preset=high" nice -n 10 tools/ab_shot.sh $S/shots/mut/N2N_b2fix $ARGS --shot-times=2
grep -a "SHADER ERROR\|SCRIPT ERROR\|Shader compilation failed" $S/shots/mut/N2N_b2fix_modern.log | head -5
cp $WT/$F $S/mut/$F
echo "x_b2fix done"
