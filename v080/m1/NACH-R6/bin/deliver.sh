#!/usr/bin/env bash
# NACH-R6: copy the pictures for review into deliver/NACH-R6 (JPEG).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-R6/shots
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/NACH-R6
mkdir -p "$D"
c() { convert "$S/$1" -quality 88 "$D/$2"; }
c grenze_12_ab_01.jpg 01_dev_grenze_tag_mittel_A_M.jpg
c grenze_12_ab_02.jpg 02_dev_grenze_tag_nah_A_M.jpg
c tri_grenze_12_01.jpg 03_dev_grenze_tag_arcade_basis_kopf.jpg
c crop_grenze12_02.png 04_ausschnitt_dev_grenze_nah_rechts_ohne_stuetze.jpg
c crop_grenze12_00.png 05_ausschnitt_dev_grenze_fern_masten.jpg
c tri_grenze_21_00.jpg 06_dev_grenze_nacht_arcade_basis_kopf.jpg
c wp_grenze_12_ab_01.jpg 07_prag_grenze_tag_mittel_A_M.jpg
c wp_grenze_12_ab_02.jpg 08_prag_grenze_tag_unter_dach_A_M.jpg
c ziel_12_ab_01.jpg 09_dev_ziel_tag_A_M.jpg
c tri_ziel_21_01.jpg 10_dev_ziel_nacht_arcade_basis_kopf.jpg
c tri_start_21_00.jpg 11_dev_start_nacht_countdown_arcade_basis_kopf.jpg
c start_21_ab_01.jpg 12_dev_start_nacht_los_A_M.jpg
c tri_tank_21_00.jpg 13_dev_tankstelle_nacht_anfahrt_arcade_basis_kopf.jpg
c tri_tank_21_01.jpg 14_dev_tankstelle_nacht_arcade_basis_kopf.jpg
c crop_tank21_shop_A_B_H.png 15_ausschnitt_tankstelle_nacht_shop_arcade_basis_kopf.jpg
ls -la "$D"
