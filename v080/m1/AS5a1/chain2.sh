#!/usr/bin/env bash
# AS5a1 scratch (successor): review + delivery pictures of german_old and hanse, tint sheet, measurements - one after the other.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5a1
cd "$S"
OLD=props/city_german_old_fachwerk,props/city_german_old_fachwerk_b,props/city_german_old_barock
HAN=props/city_hanse_gabled,props/city_hanse_kontor,props/city_hanse_speicher,props/city_hanse_crane
GER=props/city_german_house,props/city_german_mietshaus,props/city_german_gruenderzeit,props/city_german_office
./deliver_style.sh altstadt "$OLD" 9 > "$S/deliver_old.log" 2>&1
./deliver_style.sh hanse "$HAN" 9 > "$S/deliver_hanse.log" 2>&1
./k4.sh "$S/shots/tint.png" tint_scene --mode=tint --dist=35 --look=race --hour=12 --preset=high \
  --items="props/city_german_house@15#e8b8a4;props/city_german_mietshaus@12#e0b09c;props/city_german_mietshaus@12#f6eee2;props/city_german_gruenderzeit@9#f6eedc;props/city_german_gruenderzeit@9#ece4d0" > "$S/tint.log" 2>&1
convert "$S/shots/tint.png" -quality 88 "$D/toenungen.jpg"
./measure.sh texel "$GER,$OLD,$HAN" > "$S/meas_texel.log" 2>&1
./measure.sh lods "$GER" ger > "$S/meas_lods_ger.log" 2>&1
./measure.sh lods "$OLD" old > "$S/meas_lods_old.log" 2>&1
./measure.sh lods "$HAN" han > "$S/meas_lods_han.log" 2>&1
./measure.sh spark "props/city_german_mietshaus,props/city_german_gruenderzeit,props/city_german_old_fachwerk,props/city_hanse_gabled,props/city_hanse_kontor" spk > "$S/meas_spark.log" 2>&1
echo "=== chain2 fertig $(date +%H:%M)" >> "$S/meas_spark.log"
