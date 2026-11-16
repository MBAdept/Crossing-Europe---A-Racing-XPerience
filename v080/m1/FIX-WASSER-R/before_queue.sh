#!/usr/bin/env bash
# FIX-WASSER-R: (1) two mutations of props.gd against the new unit tests, (2) the "before" pictures (Modern only)
# with the props.gd of the base 0ad9012 set in. props.gd is restored from HEAD at the end (also on an error).
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER-R
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bdb6e1e1-c64-3
F=scripts/race3d/builders/props.gd
cd "$WT" || exit 1
restore() {
	cd "$WT" && git checkout HEAD -- "$F" && git status --short && echo "restored $(date -u +%T)"
}
trap restore EXIT
export XDG_DATA_HOME=$S/xdg
echo "== Mutation M1: kein Ersatz-Set für prozedurale Wahrzeichen $(date -u +%T)"
python3 - "$F" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
old = 'fb = str((inp.get("lm_fallback", {}) as Dictionary).get(set_id, ""))'
assert old in s
open(p, 'w').write(s.replace(old, 'fb = ""'))
EOF
nice -n 5 tools/run_tests.sh test_props 2>&1 | grep -E '^(ok|FAIL)|Tests,' | sed 's/^/    /'
git checkout HEAD -- "$F"
echo "== Mutation M2: Pylon nicht dunkel $(date -u +%T)"
python3 - "$F" <<'EOF'
import sys
p = sys.argv[1]
s = open(p).read()
old = 'dark = not landmark and bool(it.get("prefer_proc", false))'
assert old in s
open(p, 'w').write(s.replace(old, 'dark = false'))
EOF
nice -n 5 tools/run_tests.sh test_props 2>&1 | grep -E '^(ok|FAIL)|Tests,' | sed 's/^/    /'
git checkout HEAD -- "$F"
echo "== Vorher-Bilder mit props.gd aus 0ad9012 $(date -u +%T)"
git show 0ad9012353855295255c27dd987b90e30ff0f33f:$F > "$F"
B=$S/before
mkdir -p "$B"
KH="--stage=kiel_hamburg --from=kiel --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --traffic-warmup --start-speed=80"
GFX_ARGS="--gfx-preset=high" bash "$S/modern_only.sh" "$B/kb_nacht_high" $KH --hour=22 --start-km=77.6 --shot-times=0.3,2,4,6
GFX_ARGS="--gfx-preset=high" bash "$S/modern_only.sh" "$B/kb_tag_high" $KH --hour=12 --start-km=77.6 --shot-times=0.3,2,4,6
O="--weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --no-countdown --no-traffic --hour=12 --start-speed=80"
GFX_ARGS="--gfx-preset=high" bash "$S/modern_only.sh" "$B/belgrad" --stage=slavonski_brod_belgrad --from=slavonski_brod $O --start-km=198.6 --shot-times=0.3,2,4
echo "== fertig $(date -u +%T)"
