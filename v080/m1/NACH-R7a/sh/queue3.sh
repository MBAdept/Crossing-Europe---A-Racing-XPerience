#!/bin/bash
# NACH-R7a queue 3: warm-vs-commit probe of FIX-R7a in the merged tree m3 (HEAD + FIX-RINT + FIX-R7c + patch) and on head
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R7a
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-11
Q2=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/tasks/bbho25pmc.output
until grep -q "queue2 done" "$Q2" 2>/dev/null; do sleep 20; done
P=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R7a/probe/warm_vs_commit.gd
mkdir -p $S/m3/nach_probe $S/xdg/wvc
cp "$P" $S/m3/nach_probe/warm_vs_commit.gd
for st in saragossa_pau__saragossa kiel_hamburg__kiel; do
	km=160; [ $st = kiel_hamburg__kiel ] && km=60
	(cd $S/m3 && XDG_DATA_HOME=$S/xdg/wvc nice -n 10 timeout 1200 godot --headless --path . -s res://nach_probe/warm_vs_commit.gd -- --stage=$st --from-km=$km > $S/logs/wvc_m3_$st.log 2>&1)
	echo "$(date -u +%H:%M:%S) wvc m3 $st exit=$? $(grep 'PROBE frames' $S/logs/wvc_m3_$st.log)"
done
echo "$(date -u +%H:%M:%S) queue3 done"
