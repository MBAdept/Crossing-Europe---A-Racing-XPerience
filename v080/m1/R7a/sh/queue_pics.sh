#!/bin/bash
# R7a: the picture queue (one heavy job at a time). Log: m1/R7a/queue_pics.log
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7a
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-1
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
export TMPDIR=$S/tmp
mkdir -p "$D/ab_boegen" "$S/tmp"
echo "$(date -u +%H:%M:%S) start"
# 1. the reference positions of the sheets (same commands as RINT-M2's ab_boegen = the base pictures)
(cd "$WT" && PRESETS="high medium" tools/ab_sheet.sh "$D/ab_boegen" T4 T3 T1 T2 C1 S4 > "$S/ab_sheet.log" 2>&1)
echo "$(date -u +%H:%M:%S) ab_sheet exit=$?"
# 2. the other positions, this tree, high first
bash "$S/sh/shots.sh" mine high S0 R1 Lyon Bern Muenchen Nuernberg Belgrad Hannover R2 R3 R4 R5
# 3. the same on the base (high)
bash "$S/sh/shots.sh" base high S0 R1 Lyon Bern Muenchen Nuernberg Belgrad Hannover R2 R3 R4 R5
# 4. medium on this tree
bash "$S/sh/shots.sh" mine medium S0 R1 Lyon Bern Muenchen Nuernberg Belgrad Hannover R2 R3 R4 R5
echo "$(date -u +%H:%M:%S) done"
