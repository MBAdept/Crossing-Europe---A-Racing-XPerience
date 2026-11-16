#!/usr/bin/env bash
# AS5a2: final gates after chain_ab - determinism (second forced export of three models), sprite geometry,
# rm tools/kritik, check-keys, run_tests, golden check, golden modern-check (pictures kept).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a2
source $S/env.sh
if [ -z "${NOWAIT:-}" ]; then
	until grep -q "=== chain_ab fertig" $S/logs/chain_ab.out 2>/dev/null; do sleep 30; done
fi
cd $WT
mkdir -p $S/logs/gate
STEPS="${*:-outline det geom keys tests golden modern}"
for st in $STEPS; do
	echo "STEP $st $(date +%H:%M)"
	case $st in
	outline)
		$S/k5.sh k4_scene fin/outline --mode=outline2 "--items=props/city_french_sud;props/city_belgian_terrace;props/city_french_maison;props/city_french_immeuble;props/city_dutch_terrace;props/city_belgian_stone;props/city_paris_haussmann;props/city_swiss_chalet;props/city_dutch_canal;props/city_swiss_laube;props/city_dutch_canal_b;props/city_paris_corner" --look=race --hour=12 --preset=high | grep UMRISS ;;
	det)
		$S/tools/det.sh props/city_belgian_stone,props/city_swiss_chalet,props/city_french_sud > $S/logs/gate/det.log 2>&1
		grep -E "^DET" $S/logs/gate/det.log
		git status --short assets/models/props | head -10 ;;
	geom)
		$S/geom.sh final ;;
	keys)
		waitmem
		timeout 3600 nice -n 19 /home/user/tools/bpyenv/bin/python tools/blender/export_models.py --check-keys > $S/logs/gate/checkkeys.log 2>&1
		echo "check-keys exit $?: $(tail -3 $S/logs/gate/checkkeys.log | tr '\n' ' ')" ;;
	tests)
		rm -rf $WT/tools/kritik
		waitmem
		XDG_DATA_HOME=$S/xdg_tests nice -n 19 tools/run_tests.sh > $S/logs/gate/tests.log 2>&1
		echo "tests exit $?: $(tail -5 $S/logs/gate/tests.log | tr '\n' ' ')" ;;
	golden)
		waitmem
		nice -n 19 tools/golden.sh check > $S/logs/gate/golden.log 2>&1
		echo "golden exit $?: $(grep -E 'GOLDEN|identisch' $S/logs/gate/golden.log | tail -3 | tr '\n' ' ')" ;;
	modern)
		rm -rf $S/golden_modern; mkdir -p $S/golden_modern
		waitmem
		KEEP=$S/golden_modern nice -n 19 tools/golden.sh modern-check > $S/logs/gate/mcheck.log 2>&1
		echo "modern-check exit $?: $(tail -4 $S/logs/gate/mcheck.log | tr '\n' ' ')" ;;
	esac
done
echo "=== chain_final fertig $(date +%H:%M)"
