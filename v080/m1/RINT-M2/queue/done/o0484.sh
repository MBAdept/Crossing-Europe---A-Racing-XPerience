S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
export TMPDIR=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/tmp_ab
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1
export MESA_SHADER_CACHE_DIR=$S/mesa LP_NUM_THREADS=2 GFX_ARGS="--gfx-preset=high"
for p in TSB TSBN; do
	args=$($S/sh/pos.sh $p)
	tools/ab_shot.sh $S/ab/extra/$p $args --shot-times=1.5,2.5 > $S/ab/extra/$p.out 2>&1
	echo "ab $p exit $?"
done
