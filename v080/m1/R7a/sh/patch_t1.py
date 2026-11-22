import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
add = """**Fußabdruck – die Lücke im strengen Lesen (gemessen, `probe/intrude.gd`, 128 Richtungen):** der Requisiten-Builder
(R7c, nicht meine Datei) prüft mit `in_bend_corridor(z, x)` nur den Fuß – bei `align: edge` den Anker = Vorderkante plus
Ausdehnung. Requisiten über 0,5 m, deren Fuß außerhalb der Hülle steht, deren Vorderkante oder Krone aber hineinreicht:

| | Gebäude | Stadthäuser | Bäume | Pflanzen | Felsen | Sonstige | Summe |
|---|---|---|---|---|---|---|---|
| Basis (altes Band entscheidet) | 77 | 723 | 191 | 2 | 13 | 118 | 1.124 |
| R7a (Hülle, Fuß-Test) | 81 | 1.496 | 3.654 | 305 | 156 | 140 | 5.832 |
| mit `in_bend_corridor(z, x, reach, half_len)` | 69 | 3 | 52 | 11 | 12 | 122 | 269 |

Tiefstes Hineinragen: Stadthaus 19 m, Baum 8 m (Kronenradius). Der Rest mit Reichweite sind nicht weglassbare Objekte
(von Ereignissen gesetzte Gebäude, Windräder – die der Builder nie weglässt). Mit Reichweite kämen 15.954 statt 22.432
Stücke zurück, und 1.223, die die Basis zeichnet, fielen weg. Die zwei optionalen Argumente sind in
`ChunkContext.in_bend_corridor()` gebaut und getestet (Commit 43cfd97, Standard unverändert); der Aufruf im
Requisiten-Builder ist eine Zeile (`notes_for_next`). An C1 ist genau das die Ursache der Verdeckung bei 270 m (§4).

"""
s = s.replace("## 3. Was zurückkommt", add + "## 3. Was zurückkommt")
open(p, "w", encoding="utf-8").write(s)
print("ok" if add in s else "MISSING")
