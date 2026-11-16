#!/usr/bin/env bash
# FIX-WASSER: tools/golden.sh modern-make with kept pictures, then the old and the new MD5 list side by side
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER
cd /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-1 || exit 1
export XDG_DATA_HOME=$S/xdg_golden
export MESA_SHADER_CACHE_DIR=$S/mesa
mkdir -p "$XDG_DATA_HOME"
[ -s "$S/modern_slice_old.md5" ] || git show 3a23cb8dad346b623118fc0bcab9c0ffaea1efbf:tests/golden/modern_slice.md5 > "$S/modern_slice_old.md5"
[ -s "$S/modern_slice_old.env" ] || git show 3a23cb8dad346b623118fc0bcab9c0ffaea1efbf:tests/golden/modern_slice.env > "$S/modern_slice_old.env"
rm -rf "$S/golden_make_keep"
t0=$SECONDS
echo "start $(date -u +%T) HEAD $(git rev-parse --short HEAD)"
KEEP=$S/golden_make_keep nice -n 10 tools/golden.sh modern-make
echo "exit $? ($((SECONDS - t0)) s) $(date -u +%T)"
echo "--- alt (3a23cb8)"
cat "$S/modern_slice_old.md5"
echo "--- neu"
cat tests/golden/modern_slice.md5
echo "--- Unterschiede"
diff "$S/modern_slice_old.md5" tests/golden/modern_slice.md5
echo "--- env"
diff "$S/modern_slice_old.env" tests/golden/modern_slice.env
