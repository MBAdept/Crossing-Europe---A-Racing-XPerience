#!/usr/bin/env bash
# NACH-WASSER: queue 3 pictures against QA-WASSER's pictures of the old build (same arguments): Arcade must be
# identical; Modern differs only where the fix acts (pylons at night) – by day bit-identical expected.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/NACH-WASSER
Q=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-WASSER/shots
for scene in kb_nacht_deck kb_tag_hoch_b; do
	for m in arcade modern; do
		for f in "$S/shots/${scene}_${m}_"[0-9][0-9].png; do
			[ -s "$f" ] || continue
			n=${f##*_}
			python3 -I "$S/tools/measure.py" diff "$Q/${scene}_${m}_$n" "$f"
		done
	done
done
echo "-- pylon legs / region, night presets (frame 01: legs x518-550 and x648-690, y285-340; frame 03 region)"
for p in kb_nacht_hoch kb_nacht_mittel kb_nacht_niedrig; do
	for n in 01; do
		f="$S/shots/${p}_modern_$n.png"
		[ -s "$f" ] || continue
		python3 -I "$S/tools/measure.py" region "$f" 518 550 285 340
		python3 -I "$S/tools/measure.py" region "$f" 648 690 285 340
	done
done
