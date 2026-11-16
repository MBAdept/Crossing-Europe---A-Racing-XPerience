#!/usr/bin/env bash
# KRITIK-5a2 chain2: drive clips 50 km/h (k5_scene drive), model and sprite, medium, noon
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a2
source $K/items.sh
while pgrep -f "KRITIK-5a2/chain1.sh" > /dev/null; do sleep 30; done
for spec in SPAR:model SAMS:model SPAR:sprite SBER:model; do
  st=${spec%%:*}; as=${spec##*:}
  d=$K/clips/${st}_${as}
  [ -f $d/f_149.png ] && continue
  mkdir -p $d
  $K/k5.sh k5_scene ../clips/${st}_${as}/f --mode=drive "--items=${!st}" --as=$as --kmh=50 --secs=2.5 --from=0 --look=race --hour=12 --preset=medium | grep -v '^SWAP' | head -3
  grep '^SWAP' $K/logs/../logs/../clips/${st}_${as}/f.log 2>/dev/null | head -1
  cp $K/logs/../clips/${st}_${as}/f.log $d/f.log 2>/dev/null
done
echo "=== chain2 fertig $(date +%H:%M)"
