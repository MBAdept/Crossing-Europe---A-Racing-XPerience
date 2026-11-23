#!/bin/bash
# NACH-R7a queue 1: after the network runs - occlusion C1 (m3), pictures m3 + head, unit tests in m3
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7a
NETOUT=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/tasks/bszg3rtwc.output
until grep -q restored "$NETOUT" 2>/dev/null; do sleep 15; done
echo "$(date -u +%H:%M:%S) start queue1"
bash $S/sh/occl.sh m3 C1
bash $S/sh/shots.sh m3 C1 high
bash $S/sh/shots.sh m3 Muenchen high
bash $S/sh/shots.sh m3 T4 high
bash $S/sh/shots.sh m3 Belgrad high
bash $S/sh/shots.sh head C1 high
# unit tests of the touched areas in the merged tree (patched)
cd $S/m3 || exit 1
for f in test_props test_chunk_streamer test_structures test_terrain_profile test_sight_corridor; do
	XDG_DATA_HOME=$S/xdg/ut nice -n 10 timeout 1500 tools/run_tests.sh $f > $S/logs/m3_ut_$f.log 2>&1
	echo "$(date -u +%H:%M:%S) m3 unit $f exit=$? $(grep -E 'Tests bestanden|fehlgeschlagen|FEHLER' $S/logs/m3_ut_$f.log | tail -2 | tr '\n' ' ')"
done
echo "$(date -u +%H:%M:%S) queue1 done"
