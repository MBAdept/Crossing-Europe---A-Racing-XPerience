#!/bin/bash
# QA-BILD queue part 3: after "queue2 end" - per-hook render() attribution under Xvfb (GL path) in the Leistungstest
# scene "Stadt bei Nacht im Regen" and on the open Autobahn, preset medium.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-BILD
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-2
Q=$S/queue.log
log() { echo "$(date +%H:%M:%S) $*" >> $Q; }
until grep -q "queue2 end" $Q 2>/dev/null; do sleep 15; done
log "queue3 start"
cd $WT || exit 1
export MESA_SHADER_CACHE_DIR=$S/mesa_ab
export LP_NUM_THREADS=2
mkdir -p $S/xdg_q3
t0=$SECONDS
XDG_DATA_HOME=$S/xdg_q3 nice -n 10 timeout 1200 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
	--audio-driver Dummy --resolution 1280x720 -s $S/probe/qa_spikes.gd -- --graphics=modern --gfx-preset=medium --no-watchdog \
	--stage=dortmund_frankfurt --from=dortmund --start-km=216 --hour=22 --weather=rain --vehicle=kombi --seed=22 \
	--timescale=1 --spike-ms=15 --quit-sim=20 > $S/perf/spikes_city_night_xvfb.log 2>&1
log "city night xvfb exit=$? $((SECONDS - t0)) s"
log "queue3 end"
