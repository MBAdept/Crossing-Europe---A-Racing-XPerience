cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-1
export MESA_SHADER_CACHE_DIR=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/mesa LP_NUM_THREADS=2 GFX_ARGS="--gfx-preset=high"
mkdir -p /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/ab/extra
for spec in U1N:2 VAL:1,2.5 VALN:1,2.5 KBT:3 KBN:3 STB:2,4 STBN:2,4 TS15:3 TS15N:3 GRZ:1.5 GRZN:1.5 S0:4 KHZ:3 KHH:2 KHH195:2 KHH22:2 KIEL:2 KIEL195:2 KIEL22:2 NUE:2; do
	p=${spec%%:*}; t=${spec#*:}
	args=$(/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/sh/pos.sh $p)
	tools/ab_shot.sh /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/ab/extra/$p $args --shot-times=$t > /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2/ab/extra/$p.out 2>&1
	echo "ab $p exit $?"
done
