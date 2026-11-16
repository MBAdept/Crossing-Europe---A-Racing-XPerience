#!/usr/bin/env bash
# M2ZS1: triptychs Arcade | ZS1 | M2ZS1 of the picture series into deliver/M2ZS1/bilder, plus identity of the Arcade
# frames with the ZS1 runs (same simulation state) and the pylon measurements. Output: logs/tris.log
M=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1
S=$M/M2ZS1/shots
D=$M/../deliver/M2ZS1/bilder
R=$M/FIX-WASSER-R/shots
F=$M/FIX-WASSER/shots
T=$M/M2ZS1/sh/tri.sh
mkdir -p "$D"
same() {   # same <arcade new> <arcade zs1>
	if [ -f "$2" ]; then
		if cmp -s "$1" "$2"; then echo "  Arcade identisch mit dem ZS1-Lauf: $(basename "$1")"; else echo "  Arcade VERSCHIEDEN vom ZS1-Lauf: $(basename "$1")"; fi
	fi
}
one() {   # one <out name> <title> <prefix> <nn> <zs1 modern png or -> [<zs1 arcade png>]
	"$T" "$D/$1.jpg" "$2" "$3_arcade_$4.png" "$5" "$3_modern_$4.png"
	[ $# -ge 6 ] && same "$3_arcade_$4.png" "$6"
}
one kb_nacht_hoch_km77_7 "Köhlbrandbrücke km 77,7, 22 Uhr, Hoch (Bild 0,3 s)" "$S/kb_nacht_high" 00 "$R/kb_nacht_high_modern_00.png" "$R/kb_nacht_high_arcade_00.png"
one kb_nacht_hoch_km78_1 "Köhlbrandbrücke km 78,1, 22 Uhr, Hoch (Bild 2 s)" "$S/kb_nacht_high" 01 "$R/kb_nacht_high_modern_01.png" "$R/kb_nacht_high_arcade_01.png"
one kb_nacht_hoch_km78_8 "Köhlbrandbrücke km 78,8, 22 Uhr, Hoch (Bild 4 s)" "$S/kb_nacht_high" 02 "$R/kb_nacht_high_modern_02.png" "$R/kb_nacht_high_arcade_02.png"
one kb_nacht_hoch_km78_9 "Köhlbrandbrücke km 78,9, 22 Uhr, Hoch (Bild 4,3 s)" "$S/kb_nacht_high" 03 -
one kb_nacht_hoch_km79_7 "Köhlbrandbrücke km 79,7, 22 Uhr, Hoch (Bild 6 s)" "$S/kb_nacht_high" 04 "$R/kb_nacht_high_modern_03.png" "$R/kb_nacht_high_arcade_03.png"
one kb_tag_hoch_km78_1 "Köhlbrandbrücke km 78,1, 12 Uhr, Hoch (Bild 2 s)" "$S/kb_tag_high" 01 "$R/kb_tag_high_modern_01.png" "$R/kb_tag_high_arcade_01.png"
one kb_tag_hoch_km78_8 "Köhlbrandbrücke km 78,8, 12 Uhr, Hoch (Bild 4 s)" "$S/kb_tag_high" 02 "$R/kb_tag_high_modern_02.png" "$R/kb_tag_high_arcade_02.png"
one kb_tag_hoch_km78_9 "Köhlbrandbrücke km 78,9, 12 Uhr, Hoch (Bild 4,3 s)" "$S/kb_tag_high" 03 -
one kb_nacht_deck_km78_1 "Köhlbrandbrücke km 78,1, 22 Uhr, Steam-Deck-Stufe 1280×800 (Bild 2 s)" "$S/kb_nacht_deck" 01 "$R/kb_nacht_deck_modern_01.png" "$R/kb_nacht_deck_arcade_01.png"
one kb_nacht_deck_km78_8 "Köhlbrandbrücke km 78,8, 22 Uhr, Steam-Deck-Stufe 1280×800 (Bild 4 s)" "$S/kb_nacht_deck" 02 "$R/kb_nacht_deck_modern_02.png" "$R/kb_nacht_deck_arcade_02.png"
one kb_nacht_deck_km78_9 "Köhlbrandbrücke km 78,9, 22 Uhr, Steam-Deck-Stufe 1280×800 (Bild 4,3 s)" "$S/kb_nacht_deck" 03 -
one kb_tag_deck_km78_1 "Köhlbrandbrücke km 78,1, 12 Uhr, Steam-Deck-Stufe 1280×800 (Bild 2 s; ZS1-Bild aus einem anderen Lauf: FIX-WASSER, 60 km/h)" "$S/kb_tag_deck" 01 "$F/kb_tag_deck_modern_02.png"
one kb_tag_deck_km78_9 "Köhlbrandbrücke km 78,9, 12 Uhr, Steam-Deck-Stufe 1280×800 (Bild 4,3 s)" "$S/kb_tag_deck" 03 -
one start_deck_countdown_1s "Kiel – Hamburg km 0, Countdown 1 s, Steam-Deck-Stufe 1280×800, 12 Uhr" "$S/start_deck" 00 -
one start_deck_los_plus_1_5s "Kiel – Hamburg km 0, 1,5 s nach LOS, Steam-Deck-Stufe 1280×800, 12 Uhr" "$S/start_deck" 01 -
for nn in 00 01 02 03; do
	one "holtenau_$nn" "Holtenauer Hochbrücke (Rostock – Kiel ab km 200,0, 60 km/h), 12 Uhr, Hoch – Bild $nn" "$S/holtenau" "$nn" "$F/holtenau_modern_$nn.png" "$F/holtenau_arcade_$nn.png"
done
for nn in 00 01 02; do
	one "belgrad_$nn" "Ada-Brücke Belgrad (Slavonski Brod – Belgrad ab km 198,6, 80 km/h), 12 Uhr, Hoch – Bild $nn" "$S/belgrad" "$nn" "$R/belgrad_modern_$nn.png" "$R/belgrad_arcade_$nn.png"
done
for nn in 03 04; do
	one "belgrad_$nn" "Ada-Brücke Belgrad, 12 Uhr, Hoch – Bild $nn (ohne ZS1-Gegenstück)" "$S/belgrad" "$nn" -
done
echo "== Pylonbereich (x 500-780, y 150-350), mittlere Leuchtdichte"
for f in "$S"/kb_nacht_high_arcade_0[0-4].png "$S"/kb_nacht_high_modern_0[0-4].png "$R"/kb_nacht_high_modern_0[0-3].png; do
	python3 -I "$M/M2ZS1/sh/measure.py" region "$f"
done
