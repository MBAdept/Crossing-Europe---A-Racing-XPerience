#!/bin/bash
# Copies the evidence logs of AU-B into the deliver folder (no project files are touched).
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-B/work
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AU-B
mkdir -p "$D/belege"
{
	echo "Pegelplan Modern mit den ausgelieferten Dateien (capture_mix.gd + measure_mix.py, Echtzeit, ohne Bildschirm, Dummy-Treiber)."
	echo "Kompakt, Limousine, Gran Turismo: Lauf f3; Kombi, Sportwagen: Lauf f4 (nach der Rücknahme um 0,4 / 0,3 dB)."
	echo
	grep -A5 -E '^(kompakt|limousine|gran_turismo)_modern.wav' "$W/plan_f3_modern.log"
	grep -A5 -E '^(kombi|sportwagen)_modern.wav' "$W/plan_f4_modern.log"
	echo
	echo "Frühere Läufe (zur Streuung von Lauf zu Lauf): f1 und f2 mit den Pegeln vor der Rücknahme von Kombi und Sportwagen"
	echo "(f1 außerdem vor der Rücknahme des Kompakten um 0,5 dB), f3 = alle fünf nach dem dumpferen Lastwechselschlag."
	for f in plan_f1_modern plan_f2_modern plan_f3_modern; do
		echo "--- $f"
		grep -E 'modern.wav:|idle|full_throttle|flat_out|lift|cruise_130' "$W/$f.log"
	done
} > "$D/belege/pegelplan_modern.txt"
grep -E 'arcade.wav:|idle|full_throttle|flat_out|lift|cruise_130' "$W/plan_f1_arcade.log" > "$D/belege/pegelplan_arcade.txt"
cp "$W/qc_final2.log" "$D/belege/audio_qc_determinismus.txt"
cp "$W/shutdown20_final.log" "$D/belege/shutdown20.txt"
grep -v '^$' "$W/check_engine3_final.log" > "$D/belege/check_engine3.txt"
cp "$W/movie_final.log" "$D/belege/movie_maker_audio_sync.txt"
cp "$W/steady_s5.log" "$D/belege/stationaer_arcade_modern.txt"
cp "$W/cruise_cr2.log" "$D/belege/reisetempo_60s.txt"
cp "$W/tables_f4.md" "$D/belege/tabellen.md"
cp "$W/tests_audio_modern_final.log" "$D/belege/tests_audio_modern.txt"
[ -f "$W/tests_full_1.log" ] && cp "$W/tests_full_1.log" "$D/belege/run_tests_gesamt.txt"
[ -f "$W/golden_final.log" ] && cp "$W/golden_final.log" "$D/belege/golden_check.txt"
ls -la "$D" "$D/belege"
cp "$W/tests_full_1.log" "$D/belege/run_tests_gesamt_lauf1_e500f09.txt"
cp "$W/tests_full_2.log" "$D/belege/run_tests_gesamt_lauf2_c33809c.txt"
cp "$W/tests_unit_final.log" "$D/belege/run_tests_unit_8414002.txt"
cp "$W/movie_final2.log" "$D/belege/movie_maker_audio_sync.txt"
cp "$W/tables_f5.md" "$D/belege/tabellen.md"
rm -f "$D/belege/run_tests_gesamt.txt"
ls "$D/belege"
