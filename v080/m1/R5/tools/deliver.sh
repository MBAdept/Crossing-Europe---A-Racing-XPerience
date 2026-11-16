#!/usr/bin/env bash
# R5: the delivered pictures – triples Arcade | Modern Basis | Modern R5 with German captions, into deliver/R5/bilder
R5=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R5
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R5/bilder
mkdir -p $D
C=$R5/tools/combine.sh
B=$R5/shots/base
N=$R5/shots/new2
tri() {   # tri <name> <nn> <caption>
	local name=$1 nn=$2 cap=$3 src=${4:-$1}
	if [ -e "$N/${src}_modern_$nn.png" ] && [ -e "$B/${src}_arcade_$nn.png" ]; then
		bash $C "$D/${name}_$nn.jpg" "$cap" Arcade "$B/${src}_arcade_$nn.png" "Modern Basis 6e48405" "$B/${src}_modern_$nn.png" "Modern R5" "$N/${src}_modern_$nn.png" >/dev/null
		echo "$D/${name}_$nn.jpg"
	else
		echo "fehlt: $name $nn" >&2
	fi
}
tri u1_anfahrt 00 "U1 Gotthard, Anfahrt (Bern – Mailand km 184,3, 12 Uhr): Hügel nach Arcades Folge mit Nadelbäumen"
tri u1_anfahrt 01 "U1 Gotthard, Portal (km 185,0): Rahmen, Stirnwand, Leuchten mit Lichthof von außen, Kappe"
tri u1_innen 01 "U1 Gotthard innen (km 189,6): Fliesenpaneele, Gehwege, Kabeltrassen, Leuchten"
tri u1_ausfahrt 01 "U1 Gotthard, Ausfahrt (km 201,7): Rahmen der Ausfahrt, Notausgang links; draußen nicht überbelichtet (Umgebung)"
tri u1_ausfahrt 02 "U1 Gotthard, nach der Ausfahrt (km 202,2)"
tri somport 00 "Somport, Portal (Saragossa – Pau km 176,9): Leuchten mit Lichthof, SOS-Nische rechts"
tri somport 01 "Somport innen (km 177,7): Notausgang mit grünem Schild links"
tri somport 02 "Somport innen (km 178,6)"
tri kb_rampe 00 "Köhlbrandbrücke, Rampe (Kiel – Hamburg km 77,7, 12 Uhr)"
tri kb_rampe 01 "Köhlbrandbrücke, Deck (km 78,4): Wasser in Arcades Farbe, dünne Seile, Pylone grau"
tri kb_ende 00 "Köhlbrandbrücke, Ende (km 80,1): Natursteinböschung in Kaifarbe wie Arcade statt Wasser ins Grün"
tri kb_ende 01 "Köhlbrandbrücke, nach dem Ende (km 80,8)"
tri kb_nacht 00 "Köhlbrandbrücke 22 Uhr (km 76,9)" kb_nacht2
tri kb_nacht 02 "Köhlbrandbrücke 22 Uhr, Deck (km 78,0): Pylone dunkel, Seile, ruhiges Wasser" kb_nacht2
tri holtenau 00 "Holtenauer Hochbrücke, Anfahrt (Rostock – Kiel km 200,2): kein Wasserband am Horizont wie Arcade"
tri holtenau 01 "Holtenauer Hochbrücke (km 201,0): Kanal zwischen grünen Böschungen mit Steinschüttung"
tri b1_koeln 00 "B1 Köln, Ankunft an der Severinsbrücke (Frankfurt – Köln km 186,1): Rhein, fernes Kaiufer"
tri b1_koeln 01 "B1 Severinsbrücke (km 186,8): Pylon, Seile 0,07 m"
tri elbbruecken 00 "Elbbrücken, Fachwerk (Kiel – Hamburg km 84,0): Fachwerkträger an beiden Seiten wie Arcade"
tri elbbruecken 01 "Elbbrücken (km 84,7)"
tri stein 00 "Ludwigsbrücke Würzburg, Stein (Kassel – Würzburg km 206,0)" stein_wuerzburg
tri stein 01 "Ludwigsbrücke Würzburg (km 206,7)" stein_wuerzburg
tri dev 00 "DEV Testetappe km 48,7, 21 Uhr: Hügel und Portal" dev
tri dev 01 "DEV km 49,6: Portal nah, Stirnwand im Scheinwerfer" dev
tri dev 02 "DEV km 50,6: im Testtunnel" dev
