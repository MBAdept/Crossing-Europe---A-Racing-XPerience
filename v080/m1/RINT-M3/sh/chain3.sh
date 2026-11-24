#!/bin/bash
# RINT-M3 note 7: landmark spike probe with rendering, then time-lapse-4 runs over the spike regions; chain2 is held
# (SIGSTOP 1299) meanwhile and continued at the end
. /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M3/sh/env.sh
: # the base VALS shot has ended (its shot.sh stays a zombie while chain2 is held)
echo "SLOT FREE $(date +%T)"
for mode in drive cold; do
  home=$S/xdg/lmprobe_$mode; rm -rf $home; mkdir -p $home
  (cd $W && XDG_DATA_HOME=$home nice -n 10 timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
    --audio-driver Dummy --resolution 1280x720 -s $S/probe/lm_spike_probe.gd -- --mode=$mode --km=70 --ts=4 --secs=150 \
    > $S/probe/out/lm_${mode}_gl.log 2>&1)
  echo "probe $mode rc=$? $(date +%T)"
done
for t in head base; do MAXS=420 $S/sh/perf.sh kh4s_deck_$t $t deck kiel_hamburg 12 normal 7 4 --from=kiel --start-km=58; done
for t in head base; do MAXS=600 $S/sh/perf.sh pn4_medium_$t $t medium prag_nuernberg 12 normal 7 4 --from=prag --start-km=95; done
echo "CHAIN3 DONE $(date +%T)"
kill -CONT 1299
