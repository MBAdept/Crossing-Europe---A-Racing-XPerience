#!/bin/bash
# QA1: copy the A/B sheets into the gate-1 package with German names.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080
SRC=$S/m1/QA1/ab
DST=$S/deliver/gate1/ab_boegen
mkdir -p "$DST"
rm -f "$DST"/*.jpg "$DST"/index.txt
for f in "$SRC"/*_ab_[0-9][0-9].jpg; do
	b=$(basename "$f")
	pos=${b%%_*}
	rest=${b#*_}
	q=${rest%%_*}
	nn=${b##*_ab_}
	nn=${nn%.jpg}
	case $q in
	high) qn=hoch ;;
	auto) qn=rechner_niedrig ;;
	*) qn=$q ;;
	esac
	cp "$f" "$DST/${pos}_${qn}_${nn}.jpg"
done
cp "$SRC/uebersicht_high.jpg" "$DST/uebersicht_hoch.jpg"
cp "$SRC/uebersicht_auto.jpg" "$DST/uebersicht_rechner_niedrig.jpg"
cp "$SRC/index.txt" "$DST/index.txt"
ls "$DST" | wc -l
du -sh "$DST"
