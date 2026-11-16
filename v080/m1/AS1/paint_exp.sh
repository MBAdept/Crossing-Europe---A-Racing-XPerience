#!/usr/bin/env bash
# paint experiment: export the limousine with several paint roughness / metal values and render two views each
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1
mkdir -p $S/pexp
for combo in "0.3 0.55" "0.16 0.55" "0.16 0.25" "0.08 0.25" "0.08 0.0" "0.2 0.0"; do
	set -- $combo
	export CE_PAINT_ROUGH=$1 CE_PAINT_METAL=$2
	TAILN=2 $S/ex.sh "player/limousine" --force > $S/pexp/log_$1_$2.txt 2>&1
	$S/cs.sh pexp/p_$1_$2.png --only="player/limousine" --review --views=0,2 --cols=2 --tile=800x500 > /dev/null 2>&1
	convert $S/pexp/p_$1_$2.png -gravity NorthWest -fill white -pointsize 22 -annotate +10+10 "rough $1 metal $2" $S/pexp/p_$1_$2.png
done
convert $S/pexp/p_*.png -append $S/pexp/all.png
ls -la $S/pexp/all.png
