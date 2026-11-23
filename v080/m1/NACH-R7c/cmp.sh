#!/bin/bash
# cmp.sh <scene> <nn>: pixels differing by more than 15 % (compare -fuzz 15% -metric AE, QA-R7c's measure) between the
# head picture (NACH-R7c) and QA-R7c's base / 43a1fcc / R7c pictures and FIX-R7c's own picture of the same state.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080
N=$1
NN=$2
H=$S/m1/NACH-R7c/shots/${N}_modern_${NN}.png
[ -s "$H" ] || { echo "no head picture $H"; exit 1; }
for ref in "QA base 9b02f05:$S/deliver/QA-R7c/raw/${N}_base_${NN}.png" "QA 43a1fcc:$S/deliver/QA-R7c/raw/${N}_merge_${NN}.png" \
	"QA R7c bd1803b:$S/deliver/QA-R7c/raw/${N}_r7c_${NN}.png" "FIX-R7c own:$S/m1/FIX-R7c/shots/${N}_fix_${NN}.png" \
	"Arcade (head):$S/m1/NACH-R7c/shots/${N}_arcade_${NN}.png"; do
	lab=${ref%%:*}
	f=${ref#*:}
	[ -s "$f" ] || { echo "$N $NN vs $lab: (missing)"; continue; }
	ae=$(compare -fuzz 15% -metric AE "$H" "$f" null: 2>&1)
	ex=$(compare -metric AE "$H" "$f" null: 2>&1)
	echo "$N $NN vs $lab: >15% $ae px, exact-diff $ex px"
done
