#!/bin/bash
# scratch: one text file with the outputs behind the acceptance items
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/w0/PIPE
O=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/PIPE
P=$O/pruefprotokoll.txt
{
	echo "PIPE - Prüfprotokoll (alle Ausgaben auf der Build-VM gemessen, 4 Kerne mit anderen Aufträgen geteilt)"
	echo
	echo "=== 1 Sprite-Geometrie nach allen Hooks: tools/blender/check_sprite_geometry.py --jobs 2"
	grep -E "REIHENFOLGE|ANDERS|FEHLER|Sprite-Sets gebaut|CHECK|real" $D/geo_full2.log
	echo
	echo "=== 1a Fixture aus dem Generatorstand vor dem ersten Hook (Commit af28726) neu geschrieben, gegen die erste Fixture:"
	python3 $D/fx_compare.py $D/old/tools/blender/fixtures/geometry_v070.json $D/fixture_v070_new.json
	echo "    (das eine abweichende Feld: Blenders UV-Kugel liefert ihre Flächen in jedem Prozess in anderer Reihenfolge)"
	echo
	echo "=== 2 Prüfer: python3 tools/blender/validate_models.py --report"
	cat $D/validate.log
	echo
	echo "=== 2a Der Prüfer schlägt an (eingebaute Fehler, danach wiederhergestellt):"
	cat $D/neg_validate.log
	echo
	echo "=== 3 Bake zweimal, byte-gleich:"
	grep -E "BAKE|REPO|^ M|^\?\?" $D/det.log
	echo
	echo "=== 3a Export erzwungen wiederholt, Zwischenstände byte-gleich:"
	cat $D/det_export.log $D/det_export2.log
	echo
	echo "=== 4 Renderer-Arithmetik (unbeleuchtetes Material, ALBEDO = Wert):"
	cat $D/probe_dark.log
	echo
	echo "=== 5 Eiche: lod1 gegen Fernbild (Anzeigewerte der Krone, vier Sonnenrichtungen bei Tag, Mondlicht, Mondlicht x4):"
	cat $D/tree_cal_final.log
	echo
	echo "=== 6 tools/run_tests.sh (ganzer Lauf auf dem eingecheckten Stand)"
	if [ -f $D/run_tests_final.log ]; then
		grep -E "geprüft|Tests, |test_model_db|CHECKS OK|==>|^FAIL|SCRIPT ERROR|real" $D/run_tests_final.log
		echo "CHECK-Zeilen OK: $(grep -c '^CHECK .* OK' $D/run_tests_final.log), fehlgeschlagen: $(grep -c '^CHECK .* FEHL' $D/run_tests_final.log)"
	fi
} > $P
wc -l $P
