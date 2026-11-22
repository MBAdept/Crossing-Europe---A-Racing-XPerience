#!/usr/bin/env bash
# QA-R7b: render checks (the files the package touches or must keep holding) and the Arcade golden check, on the head.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7b
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-4
G=$S/gates
mkdir -p $G $S/xdg_rc
cd $W || exit 1
export XDG_DATA_HOME=$S/xdg_rc
export MESA_SHADER_CACHE_DIR=$S/mesa
for f in ${FILES:-landmarks_render start_km0 terrain_cover light_base instance_budget.gd instance_budget_stadt props_render occlusion seam_render modern_render}; do
	out=$G/rc_${f%.gd}.log
	[ -s $out ] && grep -q 'RENDER-CHECK-DATEI.*OK' $out && continue
	while [ "$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)" -lt 3000 ]; do sleep 20; done
	nice -n 10 tools/run_render_checks.sh modern "$f" > $out 2>&1
	echo "rc $f exit=$? $(grep -c 'RENDER-CHECK-DATEI.*OK' $out) ok $(grep -c 'RENDER-CHECK-DATEI.*\(FEHLER\|ZEITLIMIT\)' $out) failed"
done
if [ -z "${SKIP_GOLDEN:-}" ]; then
	out=$G/golden_check.log
	if ! grep -q 'identisch' $out 2>/dev/null; then
		XDG_DATA_HOME=$S/xdg_golden nice -n 10 tools/golden.sh check > $out 2>&1
		echo "golden exit=$? $(grep -E 'GOLDEN' $out | tr '\n' ' ')"
	fi
fi
echo FINAL_GATES_DONE
