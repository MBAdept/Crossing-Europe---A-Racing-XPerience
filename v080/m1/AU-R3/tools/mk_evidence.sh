#!/usr/bin/env bash
# AU-R3: evidence file for Kiel – Hamburg / Mailand – Venedig (deterministic feed comparison and trigger logs).
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R3
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AU-R3
O=$D/pruefung_kiel_hamburg_venedig.txt
{
	echo "AU-R3 – Feed von AU-R2 (3600eb7, Kopie) gegen AU-R3 über ganze Etappen auf der echten Track, 1-m-Schritte (stage_compare.gd)"
	for f in kh hk mv vm; do echo "== $f"; grep -E '^(RESULT|STRETCH)' "$S/res/cmp_$f.log"; done
	echo
	echo "AU-R3 – Triggerlog mit Autopilot (trigger_log2.gd von AU-R), vorher = Baum auf 3600eb7, nachher = AU-R3"
	echo "== Kiel – Hamburg"
	python3 "$S/tools/diff_trig.py" "$S/trig/kh_before.log" "$S/trig/kh_after.log"
	echo "== Mailand – Venedig (ab km 255)"
	python3 "$S/tools/diff_trig.py" "$S/trig/mv_before.log" "$S/trig/mv_after.log"
	echo "-- vorher"
	python3 "$S/tools/ana_rows.py" "$S/trig/mv_before.log"
	echo "-- nachher"
	python3 "$S/tools/ana_rows.py" "$S/trig/mv_after.log"
} > "$O" 2>&1
echo "ok -> $O ($(wc -l < "$O") Zeilen)"
