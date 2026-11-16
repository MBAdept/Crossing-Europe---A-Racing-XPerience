# AU-R – Fahrbahnklang: nur die gemessenen Fehler behoben (Klangprofil „Modern“) – Bericht

Zweig `worktree-wf_5dca29a9-6fb-1`, gesichert als `origin/wip/v080-au-r`, Endstand **`{COMMIT}`**.
Arbeitsverzeichnis `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_5dca29a9-6fb-1`,
Basis `4209268` (Endstand AU-C1).

Deine Rückmeldung war: „die Sounds scheinen solide, auf Kopfhörer getestet; auch die Musik ist sehr gut“. Darum
behebt diese Runde **nur, was KRITIK-FAHRBAHN gemessen hat**, und hält die Klangfarbe. Die Musik ist unverändert
(kein neues Rendern; nur ein zusätzlicher Knopf `low_shelf_db`, der auf 0 steht und dann nichts tut).

**Gehört hat es hier niemand.** Alle Zahlen sind *gemessen* (diese Entwicklungsmaschine, Godot 4.7.2, ohne
Bildschirm, Dummy-Audiotreiber; die Maschine war von anderen Paketen mit belastet), sofern nicht *abgeleitet*
dabeisteht. „Vorher“ ist immer der Stand von AU-C1, mit denselben Messskripten aufgenommen.

## 1. Was sich geändert hat – worauf du achten kannst

| Was | vorher (AU-C1) | jetzt (AU-R) | worauf du achten kannst |
|---|---|---|---|
| Rollen und Wind | links und rechts dieselbe 2-s-Schleife (rechts nur versetzt gelesen): ein Pochen, das sich jede Sekunde wiederholt | jede Seite eine eigene Schleife von 4–7,6 s, Start an zufälliger Stelle, langsames Schwanken des Pegels je Seite (±1,5 dB), rechts 2 % höher | in `fahrt_kiel_hamburg_vorher_nachher` kein Takt mehr im Rauschen; die Klangfarbe soll dieselbe sein (Terzen höchstens 1 dB anders) |
| Pflaster in den Altstädten | Hamburg ganz gepflastert, Paris gar nicht (der Hash mischte nicht) | jede Altstadt zu 55–64 % gepflastert, Blöcke wechseln mit Asphalt | Hamburger Innenstadt: Asphalt → Pflaster → Asphalt (Zeiten in der .txt) |
| Betonplatten | Akzentmuster alle 8 Platten (40 m) gleich | 32 Platten je Muster; das langsame und das schnelle Muster immer im selben Takt | das „ta-tock“ bleibt, beim Beschleunigen zwischen 110 und 150 km/h kein doppelter Schlag |
| Brückenfugen | alle 24 m, auf jeder Brücke | Stahl: an den Enden und etwa alle 100 m; Beton alle 32 m; Steinbogen keine | `koehlbrandbruecke_fugen_vorher_nachher`: statt 12 nur noch 4 Fugen |
| Tankspur | rechts Rüttelstreifen, obwohl dort eine gestrichelte Linie ist | neben der Tankspur rechts glatt | (nur gemessen) |
| Tunnel | der Fahrtwind fiel um 3 dB | der Fahrtwind bleibt | Tunnel nicht plötzlich leiser |
| Aufprall | immer dieselben Dateien, gleich laut, Glas bei jedem Unfall | Glas, Kleinteile, Lkw-Schlag je 4 Varianten; jede Schicht ±2 dB und bis 20 ms versetzt; Glas ab 80 km/h Schließgeschwindigkeit, darunter in 40 %; der tiefe Schlag schwerer Unfälle 2,5 dB leiser (der neue Begrenzer nimmt sonst bis 4 dB) | `aufprall_abwechslung_neu`: kein Unfall klingt wie der vorige; ob die schweren noch genug Wucht haben, ist deine Entscheidung |
| Vorbeifahrten an Pfosten, Bäumen, Gebäuden | jede gleich laut, Varianten reihum | Variante zufällig, ±2 dB | – |
| Quietschen | immer dieselbe Tonhöhe | jedes Quietschen ±5 % | – |
| Schnee | gedämpftes Schotter-Prasseln | eigene Schleife: weiches Knirschen | `schnee_neu` |
| laute Momente | Unfall und schlimmster Fall bei Gesamtlautstärke 1,0 bis −0,5 dBTP | Begrenzer im Modern-Zweig (−2 dB): alles höchstens −1,6 dBTP | nichts sollte übersteuern |

