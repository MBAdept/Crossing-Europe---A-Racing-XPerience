#!/usr/bin/env bash
# R3 scratch: A/B pictures of real simulation states (tools/ab_shot.sh) for the report.
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_2e14ac26-9d4-1
A=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R3/ab
export MESA_SHADER_CACHE_DIR=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R3/mesa
cd "$WT"
export GFX_ARGS="--gfx-preset=medium"
nice -n 10 tools/ab_shot.sh $A/s1_tag S1 --shot-times=2,4
nice -n 10 tools/ab_shot.sh $A/s1_nacht S1 --hour=22 --shot-times=2,4
nice -n 10 tools/ab_shot.sh $A/dicht --stage=dortmund_frankfurt --from=dortmund --start-km=197.5 --hour=17.5 --weather=normal \
	--vehicle=limousine --seed=8 --autopilot --autopilot-target=150 --autopilot-refuel=never --no-countdown --traffic-warmup \
	--start-speed=120 --shot-times=3,6
nice -n 10 tools/ab_shot.sh $A/s3_tag S3 --shot-times=2
GFX_ARGS="--gfx-preset=high" nice -n 10 tools/ab_shot.sh $A/s1_hoch S1 --shot-times=4
