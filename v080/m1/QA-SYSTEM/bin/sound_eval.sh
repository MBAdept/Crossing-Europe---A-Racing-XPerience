#!/bin/bash
# Evaluation of the captures in sound/: dropouts, click candidates, balance, spectrograms (sound_analyze.py) and
# loudness per phase against the plan (tools/audio/modern/measure_mix.py).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-SYSTEM
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ae4df3ba-14f-3
python3 "$S/bin/sound_analyze.py" "$S/sound" "$S/sound/eval"
cd "$WT" || exit 2
for f in "$S"/sound/*.wav; do
	echo "== $(basename "$f")"
	python3 tools/audio/modern/measure_mix.py "$f" 2>&1 | head -30
done
