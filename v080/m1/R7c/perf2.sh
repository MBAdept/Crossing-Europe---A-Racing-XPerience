#!/usr/bin/env bash
# R7c: the perf comparison again without any other job of mine running – alternating R7c / base, two rounds
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c
G=$S/gates
for r in 1 2; do
	"$S/stage.sh" r7c_kh_medium_r$r medium kiel_hamburg kiel 12 40 >> "$G/perf2.log" 2>&1
	BASE=1 "$S/stage.sh" base_kh_medium_r$r medium kiel_hamburg kiel 12 40 >> "$G/perf2.log" 2>&1
done
echo "$(date +%H:%M) perf2 $(tr '\n' ' ' < $G/perf2.log)" >> "$G/summary.txt"
