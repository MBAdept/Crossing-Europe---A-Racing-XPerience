#!/usr/bin/env bash
# R6: perf runs (whole DEV stage at 21:00, Modern) on the head and on the base copy, presets medium and deck.
# Runs that already have a RUN line are skipped (restart-safe).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R6
WT=/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-1
for p in medium deck; do
	for w in head base; do
		if [ -s "$S/perf_${w}_$p.log" ] && grep -q "^RUN " "$S/perf_${w}_$p.log"; then
			echo "skip $w $p (done)"
			continue
		fi
		P=$WT
		[ "$w" = base ] && P=$S/base
		echo "== $w $p $(date +%H:%M) load $(cut -d' ' -f1 /proc/loadavg)"
		PRESET=$p bash "$S/bin/perf.sh" "${w}_$p" "$P"
	done
done
echo "PERF_ALL DONE $(date +%H:%M)"
