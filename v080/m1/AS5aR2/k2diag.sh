#!/usr/bin/env bash
# AS5aR2 K2 diagnosis: are far facades pale because the sun's real-time shadows end (high: 170-200 m fade)?
# lodcol (lod0/lod1/sprite, same light) at 60/120/250 m: shadows as in the race (high), none, reach 1000 m
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2
source $S/env.sh
$S/install_tools.sh > /dev/null
M=props/city_paris_haussmann,props/city_swiss_chalet,props/city_swiss_laube,props/city_french_sud,props/city_belgian_stone
mkdir -p $S/logs/k2
for v in race:"" off:--shadow_m=0 far:--shadow_m=1000; do
	tag=${v%%:*}; arg=${v#*:}
	$S/k5.sh k6_scene k2/lodcol_$tag --mode=lodcol "--models=$M" --dists=60,120,250 --x=20 --sprite --look=race --hour=12 \
		--preset=high --tile=320x260 $arg > /dev/null
	grep -E "LODCOL|Schatten" $S/logs/k2/lodcol_$tag.log > $S/logs/k2/lodcol_$tag.txt
	echo "== $tag $(date +%H:%M)"
	cat $S/logs/k2/lodcol_$tag.txt
done
rm -rf $WT/tools/kritik
