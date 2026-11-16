#!/usr/bin/env bash
# AS5aR2: final gates - determinism (second forced export), sprite geometry, check-keys, pck share, tests, golden.
#   chain_final.sh [steps]  steps: det geom keys pck tests golden modern
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2
source $S/env.sh
cd $WT
mkdir -p $S/logs/gate
STEPS="${*:-det geom keys pck tests golden modern}"
for st in $STEPS; do
	echo "STEP $st $(date +%H:%M)"
	case $st in
	det)
		$S/tools/det.sh props/city_french_sud,props/city_swiss_chalet,props/city_belgian_stone > $S/logs/gate/det.log 2>&1
		grep -E "^DET" $S/logs/gate/det.log
		echo "git status models: $(git status --short assets/models | wc -l)" ;;
	geom)
		$S/geom.sh final ;;
	keys)
		waitmem
		timeout 3600 nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --check-keys > $S/logs/gate/checkkeys.log 2>&1
		echo "check-keys exit $?: $(tail -3 $S/logs/gate/checkkeys.log | tr '\n' ' ')" ;;
	pck)
		python3 $S/tools/share.py $WT 'props/city_*' > $S/logs/gate/share.log 2>&1
		tail -20 $S/logs/gate/share.log ;;
	tests)
		rm -rf $WT/tools/kritik
		waitmem
		XDG_DATA_HOME=$S/xdg_tests nice -n 19 tools/run_tests.sh > $S/logs/gate/tests.log 2>&1
		echo "tests exit $?: $(tail -5 $S/logs/gate/tests.log | tr '\n' ' ')" ;;
	golden)
		waitmem
		nice -n 19 tools/golden.sh check > $S/logs/gate/golden.log 2>&1
		echo "golden exit $?: $(grep -E 'identisch' $S/logs/gate/golden.log | tail -3 | tr '\n' ' ')" ;;
	modern)
		rm -rf $S/golden_modern; mkdir -p $S/golden_modern
		waitmem
		KEEP=$S/golden_modern nice -n 19 tools/golden.sh modern-check > $S/logs/gate/mcheck.log 2>&1
		echo "modern-check exit $?: $(tail -4 $S/logs/gate/mcheck.log | tr '\n' ' ')" ;;
	esac
done
echo "=== chain_final fertig $(date +%H:%M)"
