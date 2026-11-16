#!/usr/bin/env bash
K=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-5a2
source $K/items.sh
while pgrep -f "KRITIK-5a2/chain4.sh" > /dev/null; do sleep 20; done
mkdir -p $K/clips/SPAR_sprite
$K/k5.sh k5_scene ../clips/SPAR_sprite/f --mode=drive "--items=$SPAR" --as=sprite --kmh=50 --secs=2.5 --from=0 --look=race --hour=12 --preset=medium | grep -v '^SWAP' | head -3
echo "=== chain5 fertig $(date +%H:%M)"
