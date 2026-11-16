#!/usr/bin/env bash
# AS5a2: A/B race pictures to the delivery folder with German names and a caption strip.
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS5a2
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS5a2
declare -A CITY=([pa]="paris" [am]="amsterdam" [br]="bruessel" [tl]="toulouse" [be]="bern")
declare -A CNAME=([pa]="Paris (Lüttich–Paris km 387,5)" [am]="Amsterdam (Bremen–Amsterdam km 357,3)" [br]="Brüssel (Köln–Brüssel km 195,5)" [tl]="Toulouse (Pau–Toulouse km 192,5)" [be]="Bern (Lyon–Bern km 302,4)")
declare -A PN=([high]="hoch" [medium]="mittel")
declare -A HN=([12]="mittag" [19.5]="daemmerung" [22]="nacht")
declare -A HT=([12]="12 Uhr" [19.5]="19:30" [22]="22 Uhr")
for f in $S/ab/*_ab_*.jpg; do
	b=$(basename $f .jpg)            # e.g. pa_high_h12_ab_00
	n=${b%%_*}; rest=${b#*_}; p=${rest%%_*}; rest=${rest#*_}; h=${rest%%_*}; h=${h#h}; nn=${b##*_}
	t=$(( nn == 0 ? 2 : 4 ))
	out=rennen_${CITY[$n]}_${PN[$p]}_${HN[$h]}_${nn}.jpg
	convert "$f" -background '#1b1f27' -fill white -font DejaVu-Sans -pointsize 24 -gravity center \
		label:"${CNAME[$n]} – Voreinstellung ${PN[$p]}, ${HT[$h]}, +$t s – links Arcade, rechts Modern" +swap -append -quality 88 "$D/$out"
	echo $out
done
