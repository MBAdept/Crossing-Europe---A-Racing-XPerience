#!/usr/bin/env bash
# AS5a1 scratch (successor 3, after the door fix): delivery pictures of the re-exported styles, level swaps, tint,
# A/B at three arrivals, clip - one heavy job after the other. Waits for the determinism exports (real6_b.log).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1
cd "$S"
until grep -q "=== fertig" "$S/real6_b.log" 2>/dev/null; do sleep 15; done
echo "STEP B fertig $(date +%H:%M)"
OLD=props/city_german_old_fachwerk,props/city_german_old_fachwerk_b,props/city_german_old_barock
HAN=props/city_hanse_gabled,props/city_hanse_kontor,props/city_hanse_speicher,props/city_hanse_crane
./deliver_style.sh altstadt "$OLD" 9 > "$S/deliver_old2.log" 2>&1
echo "STEP deliver altstadt fertig $(date +%H:%M)"
./deliver_style.sh hanse "$HAN" 9 > "$S/deliver_hanse2.log" 2>&1
echo "STEP deliver hanse fertig $(date +%H:%M)"
./measure.sh lods "$OLD" old > "$S/meas_lods_old.log" 2>&1
./measure.sh lods "$HAN" han > "$S/meas_lods_han.log" 2>&1
echo "STEP lods fertig $(date +%H:%M)"
./chain3.sh tint,ab,clip
echo "=== chain4 fertig $(date +%H:%M)"
