#!/bin/bash
# usage: capture_all.sh <tag> [profile] [extra args of capture_mix.gd …]
# Records the fixed drive of tools/audio/modern/capture_mix.gd for all five cars (real time, about 50 s each) into
# work/cap/<tag>/<car>_<profile>.wav and prints the loudness per phase.
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work
R=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-2
TAG=${1:-t}
PROF=${2:-modern}
shift 2
OUT=$W/cap/$TAG
mkdir -p "$OUT" "$W/../xdg_cap"
export XDG_DATA_HOME=$W/../xdg_cap
cd "$R" || exit 1
for car in ${CARS:-kompakt kombi limousine sportwagen gran_turismo}; do
	nice -n 5 godot --headless --path . -s res://tools/audio/modern/capture_mix.gd -- --sound=$PROF --scenario=drive --vehicle=$car "$@" --out="$OUT/${car}_${PROF}.wav" 2>&1 | grep -E 'ERROR|WARNING|capture_mix' | sed -e 's#/tmp/claude-0/[^ ]*/work/##g' | cut -c1-200
done
python3 tools/audio/modern/measure_mix.py "$OUT"/*_${PROF}.wav --json "$OUT/measure_${PROF}.json" | sed -e 's#/tmp/claude-0/[^ ]*/work/##g'
echo FERTIG
