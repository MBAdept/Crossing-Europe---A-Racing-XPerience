#!/usr/bin/env bash
# QA-R5: deliverable sheets Arcade | Modern base 6e48405 | Modern R5 5558bdc per place and shot.
Q=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R5
RB=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R5/shots/base
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-R5/bilder
mkdir -p $D
# place  base-name(R5 dir or "own:<name>")  title
while read -r place base title; do
	for n in 00 01 02 03; do
		a=$Q/shots/new/${place}_arcade_$n.png
		m=$Q/shots/new/${place}_modern_$n.png
		[ -f "$m" ] || continue
		case "$base" in
		own:*) b=$Q/shots/base/${base#own:}_modern_$n.png ;;
		-) b=/nonexistent ;;
		*) b=$RB/${base}_modern_$n.png ;;
		esac
		python3 $Q/tools/sheet.py $D/${place}_$n.jpg "$title, Bild $n (Arcade | Modern Basis 6e48405 | Modern R5 5558bdc; Modern --gfx-preset=${PRESET:-high})" \
			"Arcade=$a" "Modern Basis=$b" "Modern R5=$m" >/dev/null
	done
done <<'EOF'
u1_anfahrt u1_anfahrt U1_Gotthard_Anfahrt_12h_km183.6
u1_innen u1_innen U1_Gotthard_innen_12h_km188
u1_ausfahrt u1_ausfahrt U1_Gotthard_Ausfahrt_12h_km200.3
u1_nacht own:u1_nacht U1_Gotthard_Anfahrt_22h_km183.6
somport somport Somport_12h_km176.3
kb_rampe kb_rampe Koehlbrandbruecke_Rampe_12h_km77.2
kb_ende kb_ende Koehlbrandbruecke_Ende_12h_km79.6
kb_top own:kb_top Koehlbrandbruecke_Pylonspitzen_22h_km75.6
kb_nacht kb_nacht2 Koehlbrandbruecke_22h_km76.4
holtenau holtenau Holtenauer_Hochbruecke_12h_km199.6
b1_koeln b1_koeln B1_Severinsbruecke_Koeln_12h_km185.6
elbbruecken elbbruecken Elbbruecken_Fachwerk_12h_km83.5
stein stein_wuerzburg Ludwigsbruecke_Wuerzburg_Stein_12h_km205.5
dev dev DEV_dev_testetappe_21h_km48
EOF
ls $D | wc -l
