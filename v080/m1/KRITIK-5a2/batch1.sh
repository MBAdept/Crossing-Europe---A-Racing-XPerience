#!/usr/bin/env bash
# KRITIK-5a2 batch1: dist sheets (5 styles x 12/19.5/22, high) + close-ups (12/22, high)
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a2
source $K/items.sh
for st in PAR DUT BEL FRA SWI; do
  for h in 12 19.5 22; do
    [ -f $K/shots/dist/${st}_h$h.png ] && continue
    $K/k5.sh k4_scene dist/${st}_h$h --mode=dist2 "--items=${!st}" --dist=10,30,100,250 --sprite --look=race --hour=$h --preset=high --tile=480x400 | head -2
  done
done
for st in PAR DUT BEL FRA SWI; do
  for h in 12 22; do
    [ -f $K/shots/close/${st}_h$h.png ] && continue
    $K/k5.sh k4_scene close/${st}_h$h --mode=close "--items=${!st}" --views=road,oblique,front,back --look=race --hour=$h --preset=high | head -2
  done
done
echo "=== batch1 fertig $(date +%H:%M)"
