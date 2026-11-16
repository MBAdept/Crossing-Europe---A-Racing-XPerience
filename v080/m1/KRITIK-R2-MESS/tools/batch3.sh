#!/bin/bash
# KRITIK-R2-MESS batch 3: seams (obj), slab starts/realignments (obj, normal + forced), Godot restart test, CPU
# (obj/c1 interleaved, concrete + asphalt), preview drive re-capture (obj, r, c1). One after the other, nice 19.
W=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R2-MESS
T=$W/tools
export XDG_DATA_HOME="$W/xdg/run"
mkdir -p "$W/cap/seam" "$W/cap/slab" "$W/cap/restart" "$W/cap/drive" "$W/logs"
V=res://assets/audio/modern/vehicle
g() {
	local head=$1 log=$2 to=$3 script=$4; shift 4
	local t0=$(date +%s)
	( cd "$W/heads/$head" && nice -n 19 timeout "$to" godot --headless --path . --audio-driver Dummy -s "$script" -- --graphics=arcade "$@" ) > "$W/logs/$log.log" 2>&1
	echo "--- $head $log exit $? in $(( $(date +%s) - t0 )) s ($(date +%T))"
	grep -E "SCRIPT ERROR|Parse Error|leaked|still in use|kr_|PERF road|PERF feed|PERF impact|drive_demo" "$W/logs/$log.log" | cut -c1-240 | head -8
}
steps=${*:-S2 Vc1 seam slab restart probe perf drive Bx}
for s in $steps; do
	echo "=== $s $(date +%T)"
	case $s in
		S2)
			bash $T/run_cap.sh c1 $T/plan_mS2.json S2 --seed=7701
			bash $T/run_cap.sh obj $T/plan_mS2.json S2 --seed=7701 ;;
		Vc1)
			bash $T/run_cap.sh c1 $T/plan_mV.json V --seed=7501 --only=conc200_r0,vmax_full ;;
		seam)
			n=0
			for grp in "tyre_asphalt tyre_asphalt_b tyre_concrete tyre_concrete_b tyre_cobbles tyre_cobbles_b tyre_deck tyre_deck_b tyre_grass" \
				"tyre_grass_b tyre_gravel tyre_gravel_b tyre_rumble tyre_rumble_b tyre_snow tyre_snow_b tyre_wet tyre_wet_b" \
				"wind_low wind_low_b wind_mid wind_mid_b wind_high wind_high_b wind_buffet wind_buffet_b"; do
				n=$((n + 1))
				files=""
				for f in $grp; do files="$files,$V/$f.ogg"; done
				g obj "seam_$n" 300 "$T/kr_seam.gd" --out-dir="$W/cap/seam" --files="${files#,}" --seconds=17
			done
			g obj seam_4 300 "$T/kr_seam.gd" --out-dir="$W/cap/seam" --files="$V/slab_slow.wav,$V/slab_fast.wav" --seconds=17 ;;
		slab)
			g obj slab_norm 600 "$T/km_slab.gd" --out="$W/cap/slab/obj_norm"
			g obj slab_force 600 "$T/km_slab.gd" --out="$W/cap/slab/obj_force" --align-ms=0.1 ;;
		restart)
			g obj restart 300 "$T/kr_restart.gd" --out="$W/cap/restart/r" ;;
		probe)
			g obj vol_probe 120 "$T/vol_probe.gd" ;;
		perf)
			for rep in 1 2 3; do
				for h in obj c1; do
					g "$h" "perfconc${rep}_$h" 300 "$T/kr_perf_conc.gd"
					g "$h" "perfasph${rep}_$h" 300 "$T/perf_asph.gd"
				done
			done ;;
		Bx)
			bash $T/run_cap.sh obj $T/plan_mBx.json Bx --seed=7801
			bash $T/run_cap.sh c1 $T/plan_mBx.json Bx --seed=7801 ;;
		drive)
			for h in obj r c1; do
				g "$h" "drive_$h" 900 "$T/drive_ab.gd" --out="$W/cap/drive/$h.wav" --cobble-km=88.4
			done ;;
	esac
done
echo "=== batch3 fertig $(date +%T)"
