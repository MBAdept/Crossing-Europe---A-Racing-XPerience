#!/usr/bin/env bash
# R3 scratch: copies the chosen A/B pictures into the delivery folder under numbered names.
set -euo pipefail
A=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R3/ab
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R3
mkdir -p "$D"
cp "$A/s1_tag_ab_01.jpg"          "$D/01_s1_tag_spieler.jpg"
cp "$A/s1_nacht_ab_01.jpg"        "$D/02_s1_nacht_spieler.jpg"
cp "$A/dicht_ab_01.jpg"           "$D/03_dichter_verkehr.jpg"
cp "$A/s3_tag_ab_00.jpg"          "$D/04_s3_tag.jpg"
cp "$A/s1_hoch_ab_00.jpg"         "$D/05_s1_tag_hoch.jpg"
cp "$A/lkw_ueberholt_lkw_ab.jpg"  "$D/06_lkw_ueberholt_lkw.jpg"
cp "$A/lampen_tag_ab.jpg"         "$D/07_blinker_bremse_tag.jpg"
cp "$A/lampen_nacht_ab.jpg"       "$D/08_blinker_bremse_nacht.jpg"
cp "$A/schild_s1_ab.jpg"          "$D/09_schild_s1.jpg"
cp "$A/schild_s2_ab.jpg"          "$D/10_schild_s2.jpg"
cp "$A/schild_s3_ab.jpg"          "$D/11_schild_s3.jpg"
cp "$A/schild_s4_ab.jpg"          "$D/12_schild_s4.jpg"
cp "$A/schild_s5_ab.jpg"          "$D/13_schild_s5.jpg"
cp "$A/schild_nacht_ab.jpg"       "$D/14_schild_nacht.jpg"
ls -la "$D"
