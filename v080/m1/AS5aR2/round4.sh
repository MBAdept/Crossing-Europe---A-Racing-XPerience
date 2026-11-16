#!/usr/bin/env bash
# AS5aR2 round 4: probes of chalet, immeuble, laube, corner (+ haussmann from r1), pictures, A/B Paris night
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2
cd $S
./tools/cycle.sh probe props/city_swiss_chalet,props/city_french_immeuble,props/city_swiss_laube,props/city_paris_corner > $S/logs/probe4.log 2>&1
I="props/city_swiss_chalet@24.5;props/city_french_immeuble@19.1;props/city_swiss_laube@22.4;props/city_paris_corner@23.9"
./k5.sh k5_scene r4/close_h12 --mode=close "--items=$I" --views=road,oblique,front --look=race --hour=12 --preset=high > /dev/null 2>&1
./k5.sh k5_scene r4/dist_h12 --mode=dist2 "--items=$I" --dist=10,30,100,250 --sprite --look=race --hour=12 --preset=high --tile=480x400 > /dev/null 2>&1
./k5.sh k5_scene r4/dist_h22 --mode=dist2 "--items=$I" --dist=10,30,100,250 --sprite --look=race --hour=22 --preset=high --tile=480x400 > /dev/null 2>&1
echo "bilder fertig $(date +%H:%M)" >> $S/logs/probe4.log
./ab_all.sh $S/ab_r4 "pa:high:22" >> $S/logs/probe4.log 2>&1
echo done >> $S/logs/probe4.log
