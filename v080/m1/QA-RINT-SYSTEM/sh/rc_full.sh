#!/bin/bash
# Full render checks (all) on the pristine head worktree, own absolute XDG + mesa cache.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-SYSTEM
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-3
export XDG_DATA_HOME=$S/xdg/rc_full MESA_SHADER_CACHE_DIR=$S/xdg/rc_full/mesa
mkdir -p "$XDG_DATA_HOME" "$MESA_SHADER_CACHE_DIR"
date +%s > $S/out/rc_full.start
cd "$W" && nice -n 10 tools/run_render_checks.sh all > $S/out/rc_full.log 2>&1
echo "EXIT=$?" >> $S/out/rc_full.log
date +%s > $S/out/rc_full.end
