#!/usr/bin/env bash
# QA-R6: copy the picture sheets to the deliver folder (JPEG, titled)
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R6
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-R6
mkdir -p $D
title() { # in out text
	[ -f "$1" ] || { echo "fehlt: $1"; return; }
	convert "$1" -gravity north -background '#0d1424' -fill white -pointsize 26 -splice 0x40 -annotate +0+6 "$3" -quality 86 "$2"
}
V=$S/view
title $V/h01_dev_station_day.jpg $D/01_dev_tankstelle_tag.jpg "QA-R6 · DEV Tankstelle km 18,5–19,6 · 12 Uhr · Hoch · Arcade | Modern c8b18d1"
title $V/h02_dev_station_night.jpg $D/02_dev_tankstelle_nacht.jpg "QA-R6 · DEV Tankstelle km 18,5–19,6 · 21 Uhr · Hoch"
title $V/tri_station.jpg $D/03_dev_tankstelle_basis_gegen_r6.jpg "QA-R6 · Tankstelle: Arcade | Modern Basis 6e48405 | Modern R6 c8b18d1"
title $V/station_night_base_head_crop.jpg $D/03b_tankstelle_nacht_ausschnitt_basis_r6.jpg "Ausschnitt 21 Uhr: Basis (links) | R6 (rechts)"
title $V/k01_kh_fuel_day.jpg $D/04_kh_tankstelle_km15_tag.jpg "QA-R6 · Kiel–Hamburg Tankstelle (Tutorial-Stopp) km 13,4–14,2 · 12 Uhr"
title $V/k02_kh_fuel_night.jpg $D/05_kh_tankstelle_km15_nacht.jpg "QA-R6 · Kiel–Hamburg Tankstelle km 13,4–14,2 · 21 Uhr"
title $V/h03_dev_border_day.jpg $D/06_dev_grenze_tag.jpg "QA-R6 · DEV Grenze NL km 64,5–64,9 · 12 Uhr – rechts kein Pfeiler (B-01)"
title $V/h04_dev_border_night.jpg $D/07_dev_grenze_nacht.jpg "QA-R6 · DEV Grenze NL · 21 Uhr"
title $V/p01_pn_border_day.jpg $D/08_grenze_nuernberg_prag.jpg "QA-R6 · Nürnberg → Prag Grenze CZ km 129,3 · 15 Uhr"
title $V/radar.jpg $D/09_dev_blitzer_tag_nacht.jpg "QA-R6 · DEV Blitzer km 11,8, Blitz bei 0,53 s · 12 und 21 Uhr"
title $V/h07_dev_city_day.jpg $D/10_dev_stadt_tag.jpg "QA-R6 · DEV City Limits km 111 · 12 Uhr"
title $V/h08_dev_city_night.jpg $D/11_dev_stadt_nacht.jpg "QA-R6 · DEV City Limits km 111 · 21 Uhr"
title $V/k03_kh_city_night.jpg $D/12_kh_ankunft_hamburg_nacht.jpg "QA-R6 · Kiel–Hamburg Ankunft km 76 · 21 Uhr"
convert $V/h09_dev_start_day.jpg $V/h10_dev_start_night.jpg -append $V/start.jpg
title $V/start.jpg $D/13_dev_start_countdown.jpg "QA-R6 · DEV Start km 0 · Countdown 3 und LOS · 12 und 21 Uhr"
title $V/finish.jpg $D/14_dev_ziel.jpg "QA-R6 · DEV Ziel km 129,4–129,9 · 12 und 21 Uhr"
title $V/kh_sf.jpg $D/15_kh_start_und_ziel.jpg "QA-R6 · Kiel–Hamburg Start (km 0) und Ziel (km 94,2) · 12 Uhr"
convert $V/deck12.jpg $V/d03_deck_city_night.jpg -resize 1200x -append $V/deck.jpg
title $V/deck.jpg $D/16_deck_1280x800.jpg "QA-R6 · Voreinstellung deck 1280×800: Tankstelle 21 Uhr, Grenze 12 Uhr, Stadt 21 Uhr"
for f in $V/tri_*_base_*.jpg; do [ -f "$f" ] && cp "$f" $D/; done
cp $S/clipcheck/cd_tiles.jpg $D/20_r6clip_countdown_auszug.jpg
cp $S/clipcheck/tank_tiles.jpg $D/21_r6clip_tanken_auszug.jpg
cp $S/clipcheck/blitz_tiles.jpg $D/22_r6clip_blitz_auszug.jpg
cp $S/clipcheck/pol_tiles.jpg $D/23_r6clip_polizei_auszug.jpg
cp $S/clipcheck/ziel_tiles.jpg $D/24_r6clip_ziel_auszug.jpg
ls $D | wc -l
