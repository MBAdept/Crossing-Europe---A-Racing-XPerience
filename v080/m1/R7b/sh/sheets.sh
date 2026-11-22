#!/usr/bin/env bash
# R7b: one sheet per city (12:00, 19:30, 22:00 stacked) from the A/B pictures; PNG intermediates removed afterwards.
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R7b
mkdir -p $D/boegen
for c in hamburg hannover leipzig dortmund nuernberg paris bruessel belgrad calais madrid; do
	files=()
	for t in 12 195 22; do
		[ -f "$D/ab/${c}_${t}_ab_00.jpg" ] && files+=("$D/ab/${c}_${t}_ab_00.jpg")
	done
	[ ${#files[@]} -gt 0 ] || continue
	convert "${files[@]}" -resize 1600x -append -quality 85 "$D/boegen/${c}.jpg" && echo "$D/boegen/${c}.jpg"
done
files=()
for f in $D/ab_nah/*_ab_00.jpg; do [ -f "$f" ] && files+=("$f"); done
[ ${#files[@]} -gt 0 ] && convert "${files[@]}" -resize 1600x -append -quality 85 "$D/boegen/nah_prozedural.jpg" && echo "$D/boegen/nah_prozedural.jpg"
