#!/usr/bin/env bash
# R7c: chalet far light with 0.30 / 0.25, lod1 and lod0, Hoch and Mittel
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c
for p in high medium; do
	for f in 0.30 0.25; do
		"$S/k5.sh" k6_scene far/final4_${f}_$p --mode=lodcol "--models=props/city_swiss_chalet" \
			--dists=60,100,140,200,250 --x=20 --look=race --hour=12 --preset=$p --tile=200x160 --far_sun=$f --reps=lod1,lod0 \
			| grep -E "exit|LODCOL" | awk '{print $1, $2, $3, $4, $6}'
	done
done
rm -rf /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-3/tools/kritik
