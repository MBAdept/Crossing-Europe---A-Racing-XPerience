#!/usr/bin/env bash
# FIX-R6: copy the A/B pictures for review into deliver/FIX-R6 with descriptive names (JPEG only).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-R6
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/FIX-R6
O=$S/shots
mkdir -p $D
cp $O/grenze2_12_ab_00.jpg $D/01_dev_grenze_tag_mittel_masten.jpg
cp $O/grenze2_12_ab_01.jpg $D/02_dev_grenze_tag_nah.jpg
cp $O/grenze2_21_ab_00.jpg $D/03_dev_grenze_nacht_mittel.jpg
cp $O/grenze2_21_ab_01.jpg $D/04_dev_grenze_nacht_nah.jpg
cp $O/ziel_12_ab_01.jpg $D/05_dev_ziel_tag.jpg
cp $O/ziel_21_ab_01.jpg $D/06_dev_ziel_nacht.jpg
cp $O/start_12_ab_01.jpg $D/07_dev_start_tag_los.jpg
cp $O/start_21_ab_00.jpg $D/08_dev_start_nacht_countdown.jpg
cp $O/start_21_ab_01.jpg $D/09_dev_start_nacht_los.jpg
cp $O/kh_ziel_12_ab_01.jpg $D/10_kh_ziel_tag.jpg
cp $O/tank_12_ab_01.jpg $D/11_dev_tankstelle_tag.jpg
cp $O/tank_21_ab_01.jpg $D/12_dev_tankstelle_nacht_anfahrt.jpg
cp $O/tank_21_ab_02.jpg $D/13_dev_tankstelle_nacht_vorbei.jpg
cp $O/kh_tank_12_ab_01.jpg $D/14_kh_tankstelle_km15_tag.jpg
cp $O/kh_tank_21_ab_02.jpg $D/15_kh_tankstelle_km15_nacht.jpg
cp $O/deck_grenze_12_ab_00.jpg $D/16_deck_grenze_tag.jpg
cp $O/deck_tank_21_ab_00.jpg $D/17_deck_tankstelle_nacht.jpg
cp $O/deck_ziel_21_ab_00.jpg $D/18_deck_ziel_nacht.jpg
convert $O/crop_grenze01.png -quality 90 $D/19_ausschnitt_grenze_masten_vorher_gekreuzt.jpg
convert $O/crop_g2.png -quality 90 $D/20_ausschnitt_grenze_masten_tag_nacht.jpg
convert $O/crop_ziel01.png -quality 90 $D/21_ausschnitt_zieltor_fachwerk.jpg
ls $D
