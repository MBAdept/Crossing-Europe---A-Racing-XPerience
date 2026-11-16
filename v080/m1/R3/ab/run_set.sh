#!/usr/bin/env bash
# R3 scratch: the A/B pictures of the report (placed vehicles and signs), one after the other.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R3
A=$S/ab
I=$S/ab_inject.sh
$I $A/lampen_tag $A/lamps.json "Bremslicht + Blinker bei 50 m (links), 150 m (rechts), 300 m (Mitte) - Kiel-Hamburg km 2, 12 Uhr" --stage=kiel_hamburg --from=kiel --km=2 --hour=12
$I $A/lampen_nacht $A/lamps.json "Bremslicht + Blinker bei 50 m (links), 150 m (rechts), 300 m (Mitte) - Kiel-Hamburg km 2, 22 Uhr" --stage=kiel_hamburg --from=kiel --km=2 --hour=22
$I $A/lkw_ueberholt_lkw $A/trucks.json "Sattelzug ueberholt Sattelzug (rot, Blinker rechts), dahinter bremsender Pkw - Kiel-Hamburg km 2, 15 Uhr" --stage=kiel_hamburg --from=kiel --km=2 --hour=15
$I $A/schild_s1 $A/none.json "Schilder S1: Entfernungstafel Hamburg 94 km (km 1,0), 50 m voraus - 12 Uhr" --stage=kiel_hamburg --from=kiel --km=0.4 --hour=12
$I $A/schild_s2 $A/none.json "Schilder S2: Tankspur-Schild (km 13,3) - 12 Uhr" --stage=kiel_hamburg --from=kiel --km=12.7 --hour=12
$I $A/schild_s3 $A/none.json "Schilder S3: Tempolimit 120 (km 60,2) - 12 Uhr" --stage=kiel_hamburg --from=kiel --km=59.6 --hour=12
$I $A/schild_s4 $A/none.json "Schilder S4: Ortstafel Hamburg (km 75) und Tempo 50 - 12 Uhr" --stage=kiel_hamburg --from=kiel --km=74.4 --hour=12
$I $A/schild_s5 $A/none.json "Schilder S5: Vorankuendigung City Limits Hamburg 4 km (km 71) - 12 Uhr" --stage=kiel_hamburg --from=kiel --km=70.4 --hour=12
$I $A/schild_nacht $A/none.json "Schilder bei Nacht: Ortstafel Hamburg (km 75), Rueckstrahlung im Scheinwerferkegel - 22 Uhr" --stage=kiel_hamburg --from=kiel --km=74.4 --hour=22
