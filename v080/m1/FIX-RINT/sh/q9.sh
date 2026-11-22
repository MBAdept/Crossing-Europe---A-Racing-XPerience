#!/bin/bash
# queue 3: after q2 – Kiel – Hamburg under Xvfb, Deck preset, time scale 16: commit per frame, collect_by, spikes
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-RINT
W=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-4
true
echo "q9: start $(date +%T)"
export XDG_DATA_HOME=$S/xdg/stage_kh
export MESA_SHADER_CACHE_DIR=$S/mesa
export LP_NUM_THREADS=2
mkdir -p $XDG_DATA_HOME
cd $W
nice -n 10 timeout 3000 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1280x720 \
  -s $S/sh/stage_hash.gd -- --stage=kiel_hamburg --hour=12 --weather=normal --seed=7 --autopilot-refuel=auto --timescale=16 --max-seconds=2900 \
  --graphics=modern --gfx-preset=deck > $S/logs/stage_kh_deck4.log 2>&1
echo "q9: exit=$? $(date +%T)"
python3 - $S/logs/stage_kh_deck4.log <<'PY'
import json, sys
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    if line.startswith("PERF "):
        p = json.loads(line[5:])
        st = p.get("streamer", {})
        print("BUDGET preset=%s frames=%s render_ms_avg=%.2f render_ms_max=%.2f commit_ms_max=%.2f commit_ms_avg=%.2f commits=%s steps=%s" % (
            p.get("preset"), p.get("frames"), p.get("render_ms_avg", 0), p.get("render_ms_max", 0), st.get("commit_ms_max", 0), st.get("commit_ms_avg", 0),
            st.get("commits"), st.get("commit_steps")))
        print("COMMIT_BY " + json.dumps(st.get("commit_by", {}), sort_keys=True))
        print("COLLECT_BY " + json.dumps(st.get("collect_by", {}), sort_keys=True))
        print("SPIKES " + json.dumps(p.get("spikes", [])))
        print("HOOKS_MAX " + json.dumps(p.get("hooks_ms_max", {}), sort_keys=True)); print("UPDATE_MAX " + json.dumps(st.get("update_ms_max", {}), sort_keys=True))
    if line.startswith("HASHES") or line.startswith("ERGEBNIS"):
        print(line.strip()[:300])
PY
