#!/bin/bash
# resumable, on the final head d6d55b4: unit tests, all render checks, occlusion probe, Modern goldens (make)
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3/sh/env.sh
cd $W
if ! grep -q "Tests bestanden\|fehlgeschlagen" $S/gates/run_tests2.log 2>/dev/null; then
	mkdir -p $S/xdg/rt2; XDG_DATA_HOME=$S/xdg/rt2 nice -n 10 tools/run_tests.sh > $S/gates/run_tests2.log 2>&1
	echo "run_tests2 exit $?"
fi
echo "TESTS DONE $(date +%T)"
mkdir -p $S/xdg/rc; export XDG_DATA_HOME=$S/xdg/rc
for f in tests/race/check_glow_occlusion.gd tests/race/check_sprite_flip.gd $(find tests/race3d/render -maxdepth 1 -name 'check_*.gd' | sort); do
	b=$(basename $f)
	grep -qE "RENDER-CHECK-DATEI $f " $S/gates/render_checks.log 2>/dev/null && continue
	what=modern; case "$f" in tests/race/*) what=arcade ;; esac
	nice -n 10 tools/run_render_checks.sh $what $b 2>&1 | grep -vE "^==>" >> $S/gates/render_checks.log
done
echo "RENDER DONE $(date +%T)"
for t in head base; do
	for p in T1 T2 T3 T4 C1 S0 S4; do
		grep -qE "occl $t $p exit" $S/logs/occl_done.log 2>/dev/null && continue
		$S/sh/occl.sh $t $p >> $S/logs/occl_done.log 2>&1
	done
done
echo "OCCL DONE $(date +%T)"
if ! grep -q "MAKE rc=0" $S/logs/make_done.log 2>/dev/null; then
	mkdir -p $S/tmp_golden $S/gates/modern_make
	t0=$SECONDS
	(cd $W && KEEP=$S/gates/modern_make TMPDIR=$S/tmp_golden nice -n 10 tools/golden.sh modern-make > $S/gates/modern_make.log 2>&1)
	echo "MAKE rc=$? $((SECONDS - t0)) s" >> $S/logs/make_done.log
fi
cat $S/logs/make_done.log
git -C $W status --short | head
echo "SLOTA DONE $(date +%T)"
