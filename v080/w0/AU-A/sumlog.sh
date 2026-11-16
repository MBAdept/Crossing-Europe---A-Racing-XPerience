#!/usr/bin/env bash
# Summary of a tools/run_tests.sh log. Usage: sumlog.sh <log file>
L="$1"
grep -E "Tests,|^==>|^EXIT|geprüft" "$L"
echo "ok-Zeilen: $(grep -c '^ok ' "$L")  FAIL: $(grep -c '^FAIL' "$L")  CHECK OK: $(grep -cE '^CHECK .* OK ' "$L")  CHECK FEHLER: $(grep -cE '^CHECK .*FEHLER' "$L")  Fehlerzeilen: $(grep -cE '^ERROR|SCRIPT ERROR|Parse Error' "$L")"
for t in test_audio_synth test_engine_audio test_engine_bank test_engine_gearbox test_traffic_audio \
	test_arcade_identity test_modern_buses test_modern_mix test_modern_assets test_audio_feed test_modern_audio test_modern_checks; do
	echo "$t: $(grep -c "^ok    $t.gd" "$L") ok, $(grep -c "^FAIL  $t.gd" "$L") FAIL"
done
