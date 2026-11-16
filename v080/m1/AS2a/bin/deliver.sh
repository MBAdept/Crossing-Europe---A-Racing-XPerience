#!/usr/bin/env bash
# AS2a: render the review sheets (one Godot at a time, nice 19) into out/raw.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2a
R=$S/out/raw
mkdir -p "$R"
sh() { "$S/bin/sheet.sh" "$@" | tail -1; }
P="player/*"
T="traffic/suv,traffic/van,traffic/sports"
# chase camera from behind, 8 / 9 (the race) / 30 m, each next to its Arcade sprite
sh $R/01_chase_tag.png --only="$P" --chase=8,9,30 --arcade --day --tile=480x300 --cols=6
# chase camera at night: tail lights, brake + indicator
sh $R/02_chase_nacht.png --only="$P" --chase=9,30 --tile=480x300 --cols=6
# contact sheets day / night (every lamp state)
sh $R/03_tag_spieler.png --only="$P" --tile=480x320 --cols=5
sh $R/04_nacht_spieler.png --only="$P" --night --tile=400x260 --cols=10
sh $R/05_tag_verkehr.png --only="$T" --tile=480x320 --cols=6
sh $R/06_nacht_verkehr.png --only="$T" --night --tile=400x260 --cols=10
# showroom A/B (race look + AgX of the showroom)
sh $R/07_showroom_ab.png --only="$P" --showroom --tonemap=agx --tile=768x480 --cols=2
# close-ups of the player cars and of the new traffic cars
for m in kompakt kombi limousine sportwagen gran_turismo; do
	sh $R/08_nah_$m.png --only="player/$m" --review --views=0,4,12,14,19,20,6,17,18,7,13,3 --tile=640x400 --cols=4
done
sh $R/09_nah_verkehr.png --only="$T" --review --views=0,2,4,12,10,3 --tile=512x320 --cols=6
# traffic in the game camera, day and night
sh $R/10_verkehr_spielkamera.png --only="$T" --chase=10,30,80 --tile=420x260 --cols=9
# lamp channel strip
sh $R/11_kanaele.png --channels
echo fertig
