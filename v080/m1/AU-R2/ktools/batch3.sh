#!/bin/bash
# KRITIK-R batch 3: in-game seams of every Ogg loop (after), then audio_qc.py with --determinism (after copy).
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R
export XDG_DATA_HOME="$K/xdg"
mkdir -p "$K/cap/seam" "$K/logs"
V=res://assets/audio/modern/vehicle
steps=${*:-perf seam qc}
for s in $steps; do
	case $s in
		perf)
			for rep in 2 3; do
				for t in after before; do
					( cd "$K/$t" && nice -n 19 timeout 300 godot --headless --path . --audio-driver Dummy -s "$K/tools/kr_perf_conc.gd" -- \
						--graphics=arcade ) > "$K/logs/perfconc${rep}_$t.log" 2>&1
					echo "--- perf conc $rep $t exit $?"
					grep "PERF road \|PERF feed " "$K/logs/perfconc${rep}_$t.log" | cut -c1-120
				done
			done ;;
		seam)
			n=0
			for grp in "tyre_asphalt tyre_asphalt_b tyre_concrete tyre_concrete_b tyre_cobbles tyre_cobbles_b tyre_deck tyre_deck_b tyre_grass" \
				"tyre_grass_b tyre_gravel tyre_gravel_b tyre_rumble tyre_rumble_b tyre_snow tyre_snow_b tyre_wet tyre_wet_b" \
				"wind_low wind_low_b wind_mid wind_mid_b wind_high wind_high_b wind_buffet wind_buffet_b"; do
				n=$((n + 1))
				files=""
				for f in $grp; do files="$files,$V/$f.ogg"; done
				t0=$(date +%s)
				( cd "$K/after" && nice -n 19 timeout 300 godot --headless --path . --audio-driver Dummy -s "$K/tools/kr_seam.gd" -- \
					--graphics=arcade --out-dir="$K/cap/seam" --files="${files#,}" --seconds=17 ) > "$K/logs/seam_$n.log" 2>&1
				echo "--- seam group $n exit $? in $(( $(date +%s) - t0 )) s"
				grep -E "kr_seam|ERROR|leaked" "$K/logs/seam_$n.log" | cut -c1-160
			done ;;
		qc)
			t0=$(date +%s)
			mkdir -p "$K/tmp"
			( cd "$K/after" && TMPDIR="$K/tmp" nice -n 19 timeout 3000 python3 tools/audio/qc/audio_qc.py --determinism --json "$K/res/qc_after.json" ) \
				> "$K/logs/qc_after.log" 2>&1
			echo "--- audio_qc --determinism exit $? in $(( $(date +%s) - t0 )) s"
			tail -12 "$K/logs/qc_after.log" ;;
	esac
done
echo "=== batch3 fertig $(date +%T)"
