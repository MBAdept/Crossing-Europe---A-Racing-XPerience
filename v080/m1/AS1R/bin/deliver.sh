#!/usr/bin/env bash
# AS1R: render the review sheets (one Godot at a time) into out/raw.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1R
R=$S/out/raw
mkdir -p "$R"
sh() { "$S/bin/sheet.sh" "$@" | tail -1; }
sh $R/01.png --only="player/*" --chase=9,30 --tile=640x400 --cols=3
sh $R/02k.png --only="player/kompakt" --review --views=0,4,12,14,19,20,6,17,18,7,13,3 --tile=640x400 --cols=4
sh $R/02l.png --only="player/limousine" --review --views=0,4,12,14,19,20,6,17,18,7,13,3 --tile=640x400 --cols=4
sh $R/03.png --only="player/*" --review --views=12,4,18,6 --tile=640x400 --cols=4 --clay
sh $R/04.png --only="player/*" --showroom
for pair in "sedan:traffic/sedan_red" "hatch:traffic/hatch_red" "wagon:traffic/wagon_silver"; do
	m=${pair%%:*}; s=${pair#*:}
	sh $R/05_$m.png --only="traffic/$m" --review --views=0,4,6,12,2,10 --set=$s --tile=512x320 --cols=6
	sh $R/06_$m.png --only="traffic/$m" --chase=10,30,80 --set=$s --tile=480x300 --cols=3
done
sh $R/08a.png --only="traffic/truck" --chase=20,60,150 --set=traffic/truck_white --tile=480x300 --cols=3
sh $R/08b.png --only="traffic/truck" --review --views=0,4,2,3,8,9 --set=traffic/truck_red --tile=640x400 --cols=3
sh $R/09.png --review --views=2,0 --tile=480x300 --cols=4 --caster
sh $R/10p.png --only="player/*" --tile=480x320 --cols=6
sh $R/10t.png --only="traffic/*" --tile=480x320 --cols=6
sh $R/11p.png --only="player/*" --night --tile=480x320 --cols=6
sh $R/11t.png --only="traffic/*" --night --tile=480x320 --cols=6
sh $R/12.png --channels
echo fertig
