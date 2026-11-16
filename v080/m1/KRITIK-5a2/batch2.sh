#!/usr/bin/env bash
# KRITIK-5a2 batch2: lods (medium 12/22, high 12), outline2, tint, sparkcam
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a2
source $K/items.sh
G1="props/city_french_sud,props/city_french_maison,props/city_french_immeuble,props/city_belgian_terrace"
G2="props/city_belgian_stone,props/city_dutch_terrace,props/city_dutch_canal,props/city_dutch_canal_b"
G3="props/city_swiss_chalet,props/city_swiss_laube,props/city_paris_haussmann,props/city_paris_corner"
for g in G1 G2 G3; do
  for h in 12 22; do
    [ -f $K/shots/lods/${g}_m_h$h.png ] || $K/k5.sh k4_scene lods/${g}_m_h$h --mode=lods "--models=${!g}" --sprite --x=20 --look=race --hour=$h --preset=medium | grep -E "UMSCHALT|STUFEN|exit|ERROR"
  done
  [ -f $K/shots/lods/${g}_h_h12.png ] || $K/k5.sh k4_scene lods/${g}_h_h12 --mode=lods "--models=${!g}" --sprite --x=20 --look=race --hour=12 --preset=high | grep -E "UMSCHALT|STUFEN|exit|ERROR"
done
I12=$(echo $ALL12 | tr ',' ';')
[ -f $K/shots/outline.png ] || $K/k5.sh k4_scene outline --mode=outline2 "--items=$I12" --look=race --hour=12 --preset=high | grep -E "UMRISS|exit|ERROR"
[ -f $K/shots/tint.png ] || $K/k5.sh tint_scene tint --mode=tint "--items=props/city_dutch_terrace@26.6#ead6cc" --dist=35 --look=race --hour=12 --preset=high | grep -E "TINT|exit|ERROR"
for h in 12 22; do
  [ -f $K/shots/lodcol_h$h.png ] || $K/k5.sh k6_scene lodcol_h$h --mode=lodcol "--models=$ALL12" --dists=60,120,250 --x=20 --sprite --look=race --hour=$h --preset=high --tile=320x260 | grep -E "LODCOL|exit|ERROR"
done
[ -f $K/shots/spark.png ] || $K/k5.sh my_scene spark --mode=sparkcam "--models=props/city_swiss_laube,props/city_french_sud,props/city_paris_corner,props/city_dutch_canal_b,props/city_french_maison,props/city_paris_haussmann" --dists=40,60,100,150 --x=20 --sprite --look=race --hour=12 --preset=medium | grep -E "SPARK|FLIMMER|exit|ERROR"
echo "=== batch2 fertig $(date +%H:%M)"
