#!/usr/bin/env bash
# AS5a1 scratch: the real exports of all three styles, one after the other (detached; one worker, nice 19).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a1
CE_THREADS=3 "$S/cycle.sh" real props/city_german_house,props/city_german_mietshaus,props/city_german_gruenderzeit,props/city_german_office > "$S/real_german.log" 2>&1
CE_THREADS=3 "$S/cycle.sh" real props/city_german_old_fachwerk,props/city_german_old_fachwerk_b,props/city_german_old_barock > "$S/real_old.log" 2>&1
CE_THREADS=3 "$S/cycle.sh" real props/city_hanse_gabled,props/city_hanse_speicher,props/city_hanse_kontor,props/city_hanse_crane > "$S/real_hanse.log" 2>&1
echo "=== chain fertig $(date +%H:%M)" >> "$S/real_hanse.log"
