#!/usr/bin/env bash
# R7c: far light of the three models with their own far_sun (965b8a9), lod0 and lod1, Hoch and Mittel
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c
for p in high medium; do
	for mv in city_paris_haussmann:0.72 city_french_sud:0.75 house_med:0.85; do
		m=${mv%%:*}; f=${mv##*:}
		"$S/k5.sh" k6_scene far/final_${m}_$p --mode=lodcol "--models=props/$m" \
			--dists=60,100,140,200,250 --x=20 --look=race --hour=12 --preset=$p --tile=200x160 --far_sun=$f --reps=lod0,lod1 \
			| grep -E "exit|LODCOL" | awk '{print $1, $2, $3, $4, $6}'
	done
done
rm -rf /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-3/tools/kritik
