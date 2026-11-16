**FIX-R4 (`b156763`) ist eine tragfähige Grundlage für die Zusammenführung RINT-M2.** Beide hohen Befunde sind
behoben und von mir nachgemessen: die rote Säule über fernen Autos an Steigungen ist weg (rote Bildpunkte über dem
Auto bei 4 s / 6,2 s: R4 168 / 793 → **0 / 0**, Arcade 0), und der nasse Kegel im Abblendlicht liegt bei **54 gegen
Arcades 61** (R4: 108), auch unter Laternen (Köhlbrandbrücke Fahrbahn 65–68 gegen Arcade 62–67, R4 88–103). Die neuen
Prüfungen (`check_night_nass.gd`) schlagen auf **R4s echtem Code** an (1,73 × / 0,42 ×; 1.328 Bildpunkte über dem
Dach) und sind auf dem Kopf grün; die Einheitstests fangen die Mutationen U5, U8, R3 und zwei weitere. Alle Tore, die ich
gefahren habe, sind grün: Arcade **20 von 20** und **17 von 17** identisch, Modern-Änderungsmelder **6 von 6**,
**765** Einheitstests ohne Fehler, neun Render-Prüfdateien grün einschließlich der geschützten Korrekturen des ersten
Testbuilds (`check_start_km0`, `check_terrain_cover` mit K1, `check_light_base`; `test_far_ground_water`, `test_props`).
Keine eingefrorene Arcade-Datei berührt.

**Offen bleibt B3** (mittel): der silberne Gran Turismo liest sich nachts im Regen hellsilbern statt marineblau-grau
(Sättigung 0,77 × bzw. 0,70 × Arcade bei gleicher Helligkeit) – hier ist Modern **schlechter** als Arcade; das gehört
ins Lack-Paket (FIX-M2 B-06 / R7). Zwei neue niedrige Punkte: die Kosten der Laternen-Profile in Städten sind nicht
gemessen (4,2 µs je Streifen und Bild, Einzelmessung) und der Laternenweg hat keine eigene Render-Prüfung.

**Look, ehrlich gegen Arcade**: nachts im Regen ist Modern in der Stadt (Frankfurt) und auf der Köhlbrandbrücke jetzt
klar besser als Arcade – warme Laternen- und rote Rücklichtspiegelungen liegen auf der nassen Fahrbahn, die Fahrbahn ist
so hell wie bei Arcade statt cremefarben; auf der freien Autobahn (N2N) gleichwertig (Kegel etwas dezenter, Markierung
klarer, ferne Rücklichter als Streifen statt Punkt). Schlechter bleibt nur das silberne Spielerauto. Alle Zahlen
llvmpipe; Steam Deck abgeleitet.
