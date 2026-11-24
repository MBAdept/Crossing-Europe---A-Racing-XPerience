#!/bin/bash
# QA-MID: Prüfsumme Modern t12 gegen Arcade t12 je Etappe
Q=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-MID
for st in "$@"; do
  m=$(grep -h '^HASHES' $Q/runs/${st}_t12.log 2>/dev/null); a=$(grep -h '^HASHES' $Q/runs/${st}_t12_arcade.log 2>/dev/null)
  em=$(grep -h '^ERGEBNIS' $Q/runs/${st}_t12.log | sed 's/"gfx":"[a-z]*",//'); ea=$(grep -h '^ERGEBNIS' $Q/runs/${st}_t12_arcade.log | sed 's/"gfx":"[a-z]*",//')
  if [ -n "$m" ] && [ "$m" == "$a" ]; then r=GLEICH; else r=VERSCHIEDEN; fi
  if [ "$em" == "$ea" ]; then e=gleich; else e=verschieden; fi
  echo "$st hashes=$r ergebnis=$e ${m}"
done
