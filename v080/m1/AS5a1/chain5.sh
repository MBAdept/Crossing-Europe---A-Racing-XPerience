#!/usr/bin/env bash
# AS5a1 scratch (successor 3): the gates on the final head, one heavy job after the other (nice 19, one worker).
#   chain5.sh [steps: geom,tests,golden,mcheck]
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-1
STEPS=",${1:-geom,tests,golden,mcheck},"
export MESA_SHADER_CACHE_DIR=$S/mesa
cd "$WT"
waitmem() {
	while true; do
		AV=$(free -g | awk '/^Mem:/{print $7}')
		if [ "${AV:-0}" -ge 3 ]; then break; fi
		sleep 60
	done
}
if [[ $STEPS == *",geom,"* ]]; then
	waitmem
	nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/check_sprite_geometry.py --only props --jobs 1 \
		> "$S/gate_geom.log" 2>&1
	echo "STEP geom exit $? $(date +%H:%M): $(grep -E 'Sprite-Sets gebaut|CHECK' "$S/gate_geom.log" | tr '\n' ' ')"
fi
if [[ $STEPS == *",tests,"* ]]; then
	rm -rf "$WT/tools/kritik"
	waitmem
	XDG_DATA_HOME=$S/xdg_tests nice -n 19 tools/run_tests.sh > "$S/gate_tests.log" 2>&1
	echo "STEP tests exit $? $(date +%H:%M): $(tail -3 "$S/gate_tests.log" | tr '\n' ' ')"
fi
if [[ $STEPS == *",golden,"* ]]; then
	waitmem
	nice -n 19 tools/golden.sh check > "$S/gate_golden.log" 2>&1
	echo "STEP golden exit $? $(date +%H:%M): $(grep GOLDEN "$S/gate_golden.log" | tr '\n' ' ')"
fi
if [[ $STEPS == *",mcheck,"* ]]; then
	waitmem
	mkdir -p "$S/golden_modern"
	KEEP=$S/golden_modern nice -n 19 tools/golden.sh modern-check > "$S/gate_mcheck.log" 2>&1
	echo "STEP mcheck exit $? $(date +%H:%M): $(grep GOLDEN "$S/gate_mcheck.log" | tr '\n' ' ')"
fi
echo "=== chain5 fertig $(date +%H:%M)"
