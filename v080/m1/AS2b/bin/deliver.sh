#!/usr/bin/env bash
# AS2b: every raw picture of the delivery, one contact-sheet run after the other (nice 19 via sheet.sh).
# usage: deliver.sh [names...]   (no name = all)
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS2b
R=$S/out/raw
mkdir -p "$R"
SH=$S/bin/sheet.sh
want() { [ $# -eq 0 ] && return 0; for w in "${ALL[@]}"; do [ "$w" = "$1" ] && return 0; done; return 1; }
ALL=("$@")
run() { local name=$1; shift; if [ ${#ALL[@]} -eq 0 ] || printf '%s\n' "${ALL[@]}" | grep -qx "$name"; then echo "== $name"; $SH "$R/$name.png" "$@" | tail -1; fi; }
# chase camera, rear at 20 / 60 / 150 m, next to the Arcade box / sprite (day), and at night
run c_truck_white --only="traffic/truck" --chase=28.25,68.25,158.25 --arcade --tile=480x360 --cols=4
run c_truck_kinds --only="traffic/truck_tarp,traffic/truck_transport" --chase=28.25,68.25,158.25 --arcade --day --tile=480x360 --cols=4
run c_bus --only="traffic/bus" --set=traffic/bus_white --chase=26.4,66.4,156.4 --arcade --tile=480x360 --cols=4
run c_pol_de --only="police/de" --chase=22.4,62.4,152.4 --arcade --tile=400x300 --cols=5
run c_pol_be --only="police/be" --chase=22.4,62.4,152.4 --arcade --tile=400x300 --cols=5
run c_pol_it --only="police/it" --chase=22.35,62.35,152.35 --arcade --tile=400x300 --cols=5
# contact sheets
run k_pol_day --only="police/*" --lods=lod0 --tile=400x260 --cols=6
run k_pol_lods --only="police/de,police/be,police/at" --tile=400x260 --cols=7
run k_pol_night_de --only="police/de" --night --tile=400x260 --cols=6
run k_pol_night_be --only="police/be" --night --tile=400x260 --cols=6
run k_heavy_day --only="traffic/truck*,traffic/bus" --tile=440x280 --cols=4
run k_heavy_night --only="traffic/truck,traffic/bus" --night --tile=400x260 --cols=5
# close-ups
run n_pol_de --only="police/de" --review --views=0,4,7,12,15,2,3,16 --tile=600x380 --cols=4
run n_pol_be --only="police/be" --review --views=0,4,7,2,3,16 --tile=600x380 --cols=3
run n_pol_it --only="police/it" --review --views=0,4,2,3 --tile=600x380 --cols=4
run n_bus --only="traffic/bus" --set=traffic/bus_white --review --views=0,1,2,3,4,5,6,17,19,20 --tile=600x380 --cols=5
run n_truck_tarp --only="traffic/truck_tarp" --set=traffic/truck_red --review --views=0,2,4,6,17,19 --tile=600x380 --cols=3
run n_truck_cab --only="traffic/truck" --review --views=3,5,16,18 --tile=600x380 --cols=4
run n_clay --only="police/de,traffic/bus,traffic/truck_tarp" --review --views=0,3 --clay --tile=600x380 --cols=6
run n_caster --only="police/de,traffic/bus,traffic/truck_tarp" --review --views=0,3 --caster --tile=600x380 --cols=6
# LOD swaps (day, game camera): police at 40 / 120 m, heavy at 60 / 180 m
for L in lod0 lod1 lod2; do
	run p_pol_de_40_$L --only="police/de" --chase=40 --lods=$L --day --tile=480x300 --cols=1
	run p_pol_de_120_$L --only="police/de" --chase=120 --lods=$L --day --tile=480x300 --cols=1
	run p_pol_be_40_$L --only="police/be" --chase=40 --lods=$L --day --tile=480x300 --cols=1
	run p_pol_be_120_$L --only="police/be" --chase=120 --lods=$L --day --tile=480x300 --cols=1
	run p_bus_60_$L --only="traffic/bus" --set=traffic/bus_white --chase=60 --lods=$L --day --tile=480x300 --cols=1
	run p_bus_180_$L --only="traffic/bus" --set=traffic/bus_white --chase=180 --lods=$L --day --tile=480x300 --cols=1
	run p_tarp_60_$L --only="traffic/truck_tarp" --set=traffic/truck_red --chase=60 --lods=$L --day --tile=480x300 --cols=1
	run p_tarp_180_$L --only="traffic/truck_tarp" --set=traffic/truck_red --chase=180 --lods=$L --day --tile=480x300 --cols=1
done
echo "deliver.sh fertig"
