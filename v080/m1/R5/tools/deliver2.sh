#!/usr/bin/env bash
# R5 (successor 4): the delivered pictures – triples Arcade | Modern Basis | Modern R5 (Endstand) where the base was
# rendered, pairs Arcade | Modern R5 otherwise; German captions; into deliver/R5/bilder
R5=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R5
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R5/bilder
mkdir -p $D
C=$R5/tools/combine.sh
B=$R5/shots/base
tri() {   # tri <out name> <nn> <caption> <new dir> [<src name>]
	local name=$1 nn=$2 cap=$3 nd=$4 src=${5:-$1}
	local n="$R5/shots/$nd/${src}_modern_$nn.png"
	if [ -e "$n" ] && [ -e "$B/${src}_arcade_$nn.png" ] && [ -e "$B/${src}_modern_$nn.png" ]; then
		bash $C "$D/${name}_$nn.jpg" "$cap" Arcade "$B/${src}_arcade_$nn.png" "Modern Basis 6e48405" "$B/${src}_modern_$nn.png" "Modern R5" "$n" >/dev/null
		echo "$D/${name}_$nn.jpg"
	else
		echo "fehlt: $name $nn" >&2
	fi
}
pair() {  # pair <out name> <nn> <caption> <dir> [<src name>]: Arcade and Modern of the same run
	local name=$1 nn=$2 cap=$3 dir=$4 src=${5:-$1}
	local a="$R5/shots/$dir/${src}_arcade_$nn.png" n="$R5/shots/$dir/${src}_modern_$nn.png"
	if [ -e "$n" ] && [ -e "$a" ]; then
		bash $C "$D/${name}_$nn.jpg" "$cap" Arcade "$a" "Modern R5" "$n" >/dev/null
		echo "$D/${name}_$nn.jpg"
	else
		echo "fehlt: $name $nn" >&2
	fi
}
tri u1_anfahrt 00 "U1 Gotthard, Anfahrt (Bern – Mailand km 184,3, 12 Uhr): Hügel nach Arcades Folge mit Nadelbäumen" new2
tri u1_anfahrt 01 "U1 Gotthard, Portal (km 185,0): Rahmen, Stirnwand, Leuchten mit Lichthof von außen" new2
tri u1_innen 01 "U1 Gotthard innen (km 189,6): Fliesenpaneele, Gehwege, Kabeltrassen, Leuchten, kein Himmel" new2
tri u1_ausfahrt 01 "U1 Gotthard, Ausfahrt (km 201,7): Rahmen der Ausfahrt, Notausgang; draußen nicht überbelichtet wie Arcade (Umgebung, R4)" new4
tri u1_ausfahrt 02 "U1 Gotthard, an der Ausfahrt (km 202,2)" new4
pair u1_nacht 00 "U1 Gotthard 22 Uhr, Anfahrt (km 184,3): Stirnwand vom Abblendlicht bis oben angestrahlt (R4: keine Abblendkante)" new3
pair u1_nacht 01 "U1 Gotthard 22 Uhr, Portal (km 185,0): Röhre mit Leuchten; Fahrbahn in der Röhre kälter als Arcade (R4)" new3
tri somport 00 "Somport, Portal (Saragossa – Pau km 176,9): Leuchten mit Lichthof, SOS-Nische rechts" new4
tri somport 01 "Somport innen (km 177,7): Notausgang mit grünem Schild links" new4
tri somport 02 "Somport innen (km 178,6)" new4
tri kb_rampe 00 "Köhlbrandbrücke, Rampe (Kiel – Hamburg km 77,7, 12 Uhr)" new2
tri kb_rampe 01 "Köhlbrandbrücke, Deck (km 78,4): Wasser in Arcades Farbe, Seile 0,07 m, Pylone grau" new2
tri kb_ende 00 "Köhlbrandbrücke, Ende (km 80,1): Natursteinböschung in Kaifarbe wie Arcade statt Wasser ins Grün" new2
tri kb_ende 01 "Köhlbrandbrücke, nach dem Ende (km 80,8)" new2
tri kb_nacht 00 "Köhlbrandbrücke 22 Uhr (km 76,9)" new4 kb_nacht2
tri kb_nacht 01 "Köhlbrandbrücke 22 Uhr (km 77,4)" new4 kb_nacht2
tri kb_nacht 02 "Köhlbrandbrücke 22 Uhr, Deck (km 78,0): Pylone dunkel, Seile, ruhiges Wasser" new4 kb_nacht2
tri holtenau 00 "Holtenauer Hochbrücke, Anfahrt (Rostock – Kiel km 200,2): kein Wasserband am Horizont wie Arcade" new2
tri holtenau 01 "Holtenauer Hochbrücke (km 201,0): Kanal zwischen grünen Böschungen mit Steinschüttung, Land dahinter" new2
tri b1_koeln 00 "B1 Köln, Ankunft an der Severinsbrücke (Frankfurt – Köln km 186,1): Rhein, Kaimauern, fernes Ufer" new4
tri b1_koeln 01 "B1 Severinsbrücke (km 186,8): Pylon, Seile 0,07 m" new4
tri elbbruecken 00 "Elbbrücken, Fachwerk (Kiel – Hamburg km 84,0): Fachwerkträger an beiden Seiten wie Arcade" new2
tri elbbruecken 01 "Elbbrücken (km 84,7)" new2
tri stein 00 "Ludwigsbrücke Würzburg, Stein (Kassel – Würzburg km 206,0)" new2 stein_wuerzburg
tri stein 01 "Ludwigsbrücke Würzburg (km 206,7): Brüstung geschlossen statt Arcades Docken (roadside.gd, R4)" new2 stein_wuerzburg
pair damm 00 "Ponte della Libertà, Damm (Mailand – Venedig km 268,4)" new3 damm_venedig
pair damm 01 "Ponte della Libertà (km 269,0)" new3 damm_venedig
pair gracht 00 "Amsterdam, Herengracht (Bremen – Amsterdam km 361,6): Kanalbrücke" new3 gracht_amsterdam
pair gracht 01 "Amsterdam, Gracht (km 361,9)" new3 gracht_amsterdam
tri dev 00 "DEV Testetappe km 48,7, 21 Uhr: Hügel und Portal" new2
tri dev 01 "DEV km 49,6: Portal nah" new2
tri dev 02 "DEV km 50,6: im Testtunnel" new2
pair kb_nacht_deck 00 "Steam Deck (1280 × 800, Stufe deck): Köhlbrandbrücke 22 Uhr (km 76,9)" new3
pair kb_nacht_deck 02 "Steam Deck: Köhlbrandbrücke 22 Uhr, Deck (km 78,0)" new3
pair u1_innen_deck 01 "Steam Deck: U1 Gotthard innen (km 189,6)" new3
pair kb_rampe_deck 01 "Steam Deck: Köhlbrandbrücke, Deck (km 78,4)" new3
# the render check's own pictures (HUD hidden): the aviation light at 22:00 and the exit
for k in beacon U1_ausfahrt U1_innen B1; do
	f=$R5/check5/tunnel_bridge_$k.png
	[ -e "$f" ] && convert "$f" -quality 90 "$D/pruefung_$k.jpg" && echo "$D/pruefung_$k.jpg"
done
# the aviation light: the render check's picture with the two pylon tops enlarged beside it
if [ -e $R5/check5/tunnel_bridge_beacon.png ]; then
	convert $R5/check5/tunnel_bridge_beacon.png -crop 160x140+560+30 +repage -filter point -resize 514% $R5/tmp/beacon_zoom.png
	bash $C "$D/kb_flugfeuer_22uhr.jpg" "Köhlbrandbrücke 22 Uhr, km 76,4 (Render-Prüfung, HUD aus): rote Flugbefeuerung auf den Pylonspitzen, blinkt im Takt von Arcade (4 von 4)" "Modern R5" $R5/check5/tunnel_bridge_beacon.png "Pylonspitzen vergrößert" $R5/tmp/beacon_zoom.png >/dev/null && echo "$D/kb_flugfeuer_22uhr.jpg"
fi
