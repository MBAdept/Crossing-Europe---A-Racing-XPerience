#!/usr/bin/env bash
# NACH-R5 probe (nothing committed): R4's fix-r4 code (assets/ and scripts/ of git diff 6e48405..origin/wip/v080-fix-r4)
# applied on 80b8141 in the worktree, then FIX-R5's one-line change of the glare quad to exit_z; renders; ALWAYS reverts.
set -uo pipefail
N=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R5
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-8
R4=b156763
cd "$WT" || exit 1
if [ -n "$(git status --porcelain -- assets scripts)" ]; then echo "worktree not clean – abort"; git status --porcelain; exit 1; fi
git diff 6e484056ec87e2fa614061000a362feb2b5a6db8 $R4 -- assets scripts > "$N/tmp/r4.patch"
ONE='var z_quad := z_exit - 0.6'
NEW='var z_quad := ceilf(z_exit / _track.seg_len - 1.0e-6) * _track.seg_len - 0.05'
revert() {
	python3 - "$WT/scripts/race3d/environment_rig.gd" "$NEW" "$ONE" <<'PY'
import sys
p, a, b = sys.argv[1:4]
s = open(p).read()
if a in s:
    open(p, 'w').write(s.replace(a, b))
PY
	git -C "$WT" apply -R "$N/tmp/r4.patch" && echo "R4 patch reverted"
	echo "status after revert: [$(git -C "$WT" status --porcelain -- assets scripts)]"
}
git apply "$N/tmp/r4.patch" || { echo "apply failed"; exit 1; }
trap revert EXIT
echo "R4 applied: $(git status --porcelain -- assets scripts | wc -l) files"
"$N/shots.sh" r4 u1_ausfahrt u1_nacht
python3 - "$WT/scripts/race3d/environment_rig.gd" "$ONE" "$NEW" <<'PY'
import sys
p, a, b = sys.argv[1:4]
s = open(p).read()
assert s.count(a) == 1, s.count(a)
open(p, 'w').write(s.replace(a, b))
print("one-line change applied")
PY
"$N/shots.sh" r4x u1_ausfahrt
