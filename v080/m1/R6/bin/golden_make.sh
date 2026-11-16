#!/usr/bin/env bash
# R6: the Modern change detectors made new (tools/golden.sh modern-make) with the pictures kept, to look at them.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R6
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-1
G=$S/gates
mkdir -p "$G" "$S/xdg/gates"
NICE=19
if [ -e /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/lead/QA_M2_FERTIG ]; then
	NICE=10
fi
export XDG_DATA_HOME=$S/xdg/gates
export MESA_SHADER_CACHE_DIR=$S/mesa
cd "$WT" || exit 1
echo "HEAD $(git rev-parse --short HEAD)  nice $NICE  $(date +%H:%M)"
rm -rf "$G/modern_make"
T0=$SECONDS
KEEP=$G/modern_make nice -n "$NICE" tools/golden.sh modern-make > "$G/golden_modern_make.log" 2>&1
echo "== golden modern-make exit $? ($((SECONDS - T0)) s)"
grep -E "^GOLDEN|==>" "$G/golden_modern_make.log" | tail -10
git diff --stat -- tests/golden/
echo "GOLDEN_MAKE DONE $(date +%H:%M)"
