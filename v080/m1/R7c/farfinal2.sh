#!/usr/bin/env bash
# R7c: far light of the remaining houses with their shipped far_sun (lod0 to 250 m, like far078)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R7c
P=props/city_
for p in high medium; do
	for g in "a:0.78:${P}dutch_terrace,${P}french_immeuble,${P}german_gruenderzeit,${P}german_old_barock,${P}hanse_gabled,${P}hanse_kontor,${P}paris_corner,${P}swiss_laube" \
		"b:0.35:${P}swiss_chalet" "c:0.85:${P}german_old_fachwerk,${P}german_old_fachwerk_b"; do
		n=${g%%:*}; r=${g#*:}; f=${r%%:*}; m=${r#*:}
		"$S/k5.sh" k6_scene far/final2_${n}_$p --mode=lodcol "--models=$m" \
			--dists=60,100,140,200,250 --x=20 --look=race --hour=12 --preset=$p --tile=200x160 --far_sun=$f --reps=lod0 \
			| grep -E "exit|LODCOL" | awk '{print $1, $2, $3, $6}'
	done
done
rm -rf /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-3/tools/kritik
