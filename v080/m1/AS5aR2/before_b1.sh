#!/usr/bin/env bash
# AS5aR2: "before" pictures of batch 1 (AS5aR1/AS5a2 state, committed) before the real export overwrites it
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2
source $S/env.sh
cd $WT
B1="props/city_german_*,props/city_hanse_*"
mkdir -p $S/shots/vorher
waitmem
nice -n 19 tools/models_contact_sheet.sh $S/shots/vorher/kontakt_b1_tag.png "--only=$B1" --cols=4 > $S/logs/vorher_contact_tag.log 2>&1
echo "contact tag exit $?"
nice -n 19 tools/models_contact_sheet.sh $S/shots/vorher/kontakt_b1_nacht.png "--only=$B1" --cols=4 --night > $S/logs/vorher_contact_nacht.log 2>&1
echo "contact nacht exit $?"
I="props/city_german_gruenderzeit@21.0;props/city_german_mietshaus@26.6;props/city_hanse_kontor@27.4"
$S/k5.sh k5_scene vorher/b1_dist_h22 --mode=dist2 "--items=$I" --dist=10,30,100,250 --sprite --look=race --hour=22 --preset=high --tile=480x400 | tail -1
$S/k5.sh k5_scene vorher/b1_dist_h12 --mode=dist2 "--items=$I" --dist=10,30,100,250 --sprite --look=race --hour=12 --preset=high --tile=480x400 | tail -1
echo "=== vorher fertig $(date +%H:%M)"
