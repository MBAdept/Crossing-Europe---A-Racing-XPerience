#!/usr/bin/env bash
# R6: the pictures for deliver/R6 – single A/B pictures (numbered) and the A/B sheets of every element on DEV.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R6
O=$S/shots
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R6
SHEET=$S/bin/sheet.sh
mkdir -p "$D"
cp_pic() { # <source in shots> <target name>
	if [ -e "$O/$1" ]; then cp "$O/$1" "$D/$2"; echo "  $2 <- $1"; else echo "  FEHLT $1"; fi
}
cp_pic v2_start_ab_01.jpg 01_kh_start_tag_los.jpg
cp_pic v2_finish_ab_00.jpg 02_kh_ziel_tag.jpg
cp_pic v3_kh_pylon_ab_01.jpg 03_kh_tankstelle_km15_tag.jpg
cp_pic v3_kh_pylon_night_ab_01.jpg 04_kh_tankstelle_km15_nacht.jpg
cp_pic v3_kh_station_night_ab_01.jpg 05_kh_tankstelle_unter_dem_dach_nacht.jpg
cp_pic v3_station_day_ab_02.jpg 06_dev_tankstelle_tag.jpg
cp_pic v4_station_night_ab_01.jpg 07_dev_tankstelle_nacht.jpg
cp_pic v3_border_day_ab_02.jpg 08_dev_grenze_tag.jpg
cp_pic v3_border_night_ab_02.jpg 09_dev_grenze_nacht.jpg
cp_pic v3_border_prag_nuernberg_ab_01.jpg 10_prag_nuernberg_grenze.jpg
cp_pic v4_radar_day_ab_01.jpg 11_dev_blitzer_tag_blitz.jpg
cp_pic v3_radar_night_ab_01.jpg 12_dev_blitzer_nacht_blitz.jpg
cp_pic v3_city_day_ab_01.jpg 13_dev_stadt_tag.jpg
cp_pic v2_city_night_ab_01.jpg 14_dev_stadt_nacht.jpg
cp_pic v4_kh_city_night_ab_01.jpg 15_kh_stadt_nacht.jpg
cp_pic v4_dev_start_day_ab_00.jpg 16_dev_start_tag_countdown.jpg
cp_pic v4_dev_start_night_ab_00.jpg 17_dev_start_nacht_countdown.jpg
cp_pic v4_dev_finish_day_ab_00.jpg 18_dev_ziel_tag.jpg
cp_pic v4_dev_finish_night_ab_01.jpg 19_dev_ziel_nacht.jpg
cp_pic v3_deck_station_night_ab_00.jpg 20_deck_tankstelle_nacht.jpg
cp_pic v3_deck_border_day_ab_00.jpg 21_deck_grenze_tag.jpg
cp_pic v3_deck_city_night_ab_00.jpg 22_deck_stadt_nacht.jpg
echo "Bögen:"
"$SHEET" "$D/bogen_dev_tankstelle.jpg" "DEV – Tankstelle km 19,6: Tag und 21 Uhr (links Arcade, rechts Modern)" "$O/v3_station_day_ab_01.jpg" "$O/v3_station_day_ab_02.jpg" "$O/v4_station_night_ab_01.jpg" "$O/v4_station_night_ab_02.jpg"
"$SHEET" "$D/bogen_dev_grenze.jpg" "DEV – Grenze km 65 (NL): Tag und 21 Uhr" "$O/v3_border_day_ab_01.jpg" "$O/v3_border_day_ab_02.jpg" "$O/v3_border_night_ab_01.jpg" "$O/v3_border_night_ab_02.jpg"
"$SHEET" "$D/bogen_dev_stadt.jpg" "DEV – City Limits km 111: Tag und 21 Uhr" "$O/v3_city_day_ab_00.jpg" "$O/v3_city_day_ab_01.jpg" "$O/v2_city_night_ab_00.jpg" "$O/v2_city_night_ab_01.jpg"
"$SHEET" "$D/bogen_dev_start_ziel.jpg" "DEV – Start km 0 und Ziel km 130: Tag und 21 Uhr" "$O/v4_dev_start_day_ab_00.jpg" "$O/v4_dev_start_night_ab_00.jpg" "$O/v4_dev_finish_day_ab_00.jpg" "$O/v4_dev_finish_night_ab_01.jpg"
"$SHEET" "$D/bogen_dev_blitzer.jpg" "DEV – Blitzer km 12,25: Tag und 21 Uhr, vor und im Blitz" "$O/v4_radar_day_ab_00.jpg" "$O/v4_radar_day_ab_01.jpg" "$O/v3_radar_night_ab_00.jpg" "$O/v3_radar_night_ab_01.jpg"
ls -la "$D"
du -sh "$D"
