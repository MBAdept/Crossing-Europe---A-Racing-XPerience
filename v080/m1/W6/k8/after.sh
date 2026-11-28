#!/bin/bash
# K8 after the F-04 gates: bake city_paris_corner, import, manifest, validate; review views turned (yaw 0/90/180/270,
# 12 and 22 h, race look); then the gates again (Arcade check, modern-check KEEP, suite, all render checks).
# Log $S/logs/k8.log; ends with "K8 GATES DONE".
source /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/W6/env.sh
L=$S/logs/k8.log
until grep -q "GATES F04 DONE" $S/logs/gates.log; do sleep 30; done
cd $WT
if [ ! -f $S/k8/bake.done ]; then
	nice -n 10 godot --headless --path . -s res://tools/models/bake_models.gd -- --only=props/city_paris_corner > $S/logs/k8_bake.log 2>&1
	echo "$(date +%T) BAKE rc $? $(grep -E 'Modelle|FEHLER|ERROR' $S/logs/k8_bake.log | tail -1)" >> $L
	nice -n 10 godot --headless --path . --import > $S/logs/k8_import.log 2>&1
	nice -n 10 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --manifest-only > $S/logs/k8_manifest.log 2>&1
	echo "$(date +%T) MANIFEST rc $? $(tail -1 $S/logs/k8_manifest.log)" >> $L
	nice -n 10 python3 tools/blender/validate_models.py > $S/logs/k8_validate.log 2>&1
	echo "$(date +%T) VALIDATE rc $? $(tail -1 $S/logs/k8_validate.log)" >> $L
	touch $S/k8/bake.done
fi
mkdir -p $S/k8/shots
for h in 12 22; do
	for y in 0 90 180 270; do
		f=$S/k8/shots/dist_h${h}_y$y.png
		[ -f $f ] && continue
		waitmem
		sp=""; [ $y = 0 ] && sp="--sprite"
		nice -n 10 tools/models/prop_scene.sh $f --models=props/city_paris_corner,props/city_paris_haussmann --mode=dist \
			--dist=20,45,100 --x=9 $sp --yaw=$y --look=race --hour=$h --preset=high --tile=480x400 > $S/logs/k8_v_${h}_$y.log 2>&1
		echo "$(date +%T) VIEW h$h yaw$y exit $?" >> $L
	done
done
echo "$(date +%T) K8 VIEWS DONE" >> $L
G=$S/gates_k8; mkdir -p $G
step() { local n=$1; shift; [ -f $G/$n.done ] && return; local t0=$(date +%s); "$@" > $G/$n.log 2>&1; local rc=$?
	echo "$(date +%T) GATE k8_$n rc $rc $(( $(date +%s) - t0 )) s" >> $S/logs/gates.log; echo $rc > $G/$n.done; }
echo "$(date +%T) GATES K8 start head $(git rev-parse --short HEAD) (+ Arbeitsstand)" >> $S/logs/gates.log
step check env TMPDIR=$S/tmp_golden KEEP=$G/arcade_check nice -n 10 tools/golden.sh check
step modern env TMPDIR=$S/tmp_golden KEEP=$G/modern_keep nice -n 10 tools/golden.sh modern-check
step run_tests env XDG_DATA_HOME=$S/xdg_tests nice -n 10 tools/run_tests.sh
step render_all nice -n 10 tools/run_render_checks.sh all
echo "$(date +%T) GATES K8 DONE" >> $S/logs/gates.log
echo "$(date +%T) K8 GATES DONE" >> $L
