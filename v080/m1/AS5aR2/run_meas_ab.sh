#!/usr/bin/env bash
# AS5aR2: measurements, then A/B and clip, one after the other
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5aR2
$S/chain_meas.sh contact close lodcol lods spark dist outline tint mip texel > $S/logs/chain_meas.out 2>&1
$S/chain_ab.sh > $S/logs/chain_ab.out 2>&1
