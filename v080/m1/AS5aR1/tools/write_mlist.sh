#!/usr/bin/env bash
# AS5a1 scratch: tests/golden/modern_slice.md5 + .env from the frames kept by "KEEP=... tools/golden.sh modern-check"
# (the same render function as modern-make; the list in the order of tests/golden/modern_frames.txt).
set -euo pipefail
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-3
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR1/golden_modern
cd "$WT"
files=$(awk '{print $2}' tests/golden/modern_slice.md5)
(cd "$K" && md5sum $files) > tests/golden/modern_slice.md5.new
{
	echo "commit=$(git rev-parse HEAD) (Arbeitskopie geändert)"
	echo "godot=$(godot --version 2>/dev/null | tail -n 1)"
	echo "opengl=$(cat "$K"/*.log 2>/dev/null | grep -m1 '^OpenGL API' | sed 's/[[:space:]]*$//')"
} > tests/golden/modern_slice.env.new
mv tests/golden/modern_slice.md5.new tests/golden/modern_slice.md5
mv tests/golden/modern_slice.env.new tests/golden/modern_slice.env
cat tests/golden/modern_slice.md5 tests/golden/modern_slice.env
