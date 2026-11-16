#!/usr/bin/env bash
# copy the extra A/B shots and the clips into the delivery folder under descriptive names
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/RINT-M2
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/RINT-M2
E=$S/ab/extra
mkdir -p "$D/ab_weitere" "$D/clips"
cp_one() { [ -f "$E/$1" ] && cp "$E/$1" "$D/ab_weitere/$2" && echo "  $2"; }
cp_one U1N_ab_00.jpg      gotthard_innen_22uhr.jpg
cp_one VAL_ab_00.jpg      tunnel_valik_einfahrt_12uhr.jpg
cp_one VAL_ab_01.jpg      tunnel_valik_innen_12uhr.jpg
cp_one VALN_ab_00.jpg     tunnel_valik_einfahrt_22uhr.jpg
cp_one VALN_ab_01.jpg     tunnel_valik_innen_22uhr.jpg
cp_one KBT_ab_00.jpg      koehlbrandbruecke_12uhr.jpg
cp_one KBN_ab_00.jpg      koehlbrandbruecke_22uhr.jpg
cp_one STB_ab_00.jpg      steinbruecke_dresden_12uhr_a.jpg
cp_one STB_ab_01.jpg      steinbruecke_dresden_12uhr_b.jpg
cp_one STBN_ab_00.jpg     steinbruecke_dresden_22uhr_a.jpg
cp_one STBN_ab_01.jpg     steinbruecke_dresden_22uhr_b.jpg
cp_one TSB_ab_00.jpg      tankstelle_kiel_hamburg_km15_12uhr_a.jpg
cp_one TSB_ab_01.jpg      tankstelle_kiel_hamburg_km15_12uhr_b.jpg
cp_one TSBN_ab_00.jpg     tankstelle_kiel_hamburg_km15_21uhr_a.jpg
cp_one TSBN_ab_01.jpg     tankstelle_kiel_hamburg_km15_21uhr_b.jpg
cp_one GRZ_ab_00.jpg      grenze_niederlande_12uhr.jpg
cp_one GRZN_ab_00.jpg     grenze_niederlande_22uhr.jpg
cp_one S0_ab_00.jpg       start_kiel_hamburg.jpg
cp_one KHZ_ab_00.jpg      ziel_kiel_hamburg.jpg
cp_one KHH_ab_00.jpg      hamburg_mitte_12uhr.jpg
cp_one KHH195_ab_00.jpg   hamburg_mitte_19_30uhr.jpg
cp_one KHH22_ab_00.jpg    hamburg_mitte_22uhr.jpg
cp_one KIEL_ab_00.jpg     kiel_stadtrand_12uhr.jpg
cp_one KIEL195_ab_00.jpg  kiel_stadtrand_19_30uhr.jpg
cp_one KIEL22_ab_00.jpg   kiel_stadtrand_22uhr.jpg
cp_one NUE_ab_00.jpg      nuernberg_altstadt_12uhr.jpg
for c in "$S"/ab/clips/*.mp4; do [ -f "$c" ] && cp "$c" "$D/clips/" && echo "  clips/$(basename "$c")"; done
du -sh "$D"
