import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
occ = """**Verdeckungssonde (gemessen, `probe/qa_occl.gd` von FIX-M2, rotes Testauto in drei Spuren bei 25–270 m, „Hoch“,
Pixel, die sich gegen das Bild ohne Auto ändern; sichtbar ab 12 px; verlangt bis min(L, 270 m)):**

| Stelle | L | kleinste Pixelzahl bis zur verlangten Entfernung (R7a) | Basis | Ergebnis |
|---|---|---|---|---|
| T4 Saragossa – Pau km 198,8 | 118 m | 165 px bei 120 m | gleich (alle Werte bis 150 m identisch) | gehalten; bei 200 m Spur +1 jetzt 54 px statt 127 px (zurückgekehrte Felsgruppe, jenseits von L) |
| T3 km 172,8 | 119 m | 161 px bei 120 m | identisch in allen 21 Messungen | gehalten |
| T1 Kassel – Würzburg km 46,5 | 263 m | 39 px bei 200 m, 14 px bei 270 m | – | gehalten |
| T2 km 61,9 | 300 m | 22 px bei 270 m | – | gehalten |
| S0 Kiel km 0 | 300 m | 20 px bei 270 m | – | gehalten |
| S4 Kiel – Hamburg km 80 | 300 m | 18 px bei 270 m | – | gehalten |
| C1 Dortmund – Frankfurt km 221 | 300 m | 30 px bei 200 m; **bei 270 m 6/0/0 px** | **6/9/0 px** | bei 270 m schon in der Basis verdeckt (rechts ein Mietshaus an der Kurveninnenseite); R7a nimmt Spur 0 die letzten 9 px |

C1 genauer (`probe/c1_props.gd`): das Auto bei 270 m steht hinter zwei Häusern der Kurveninnenseite. Das vordere
(`city_german_mietshaus`, 219 m voraus) steht in Basis und R7a: sein Fuß liegt 18,0 m jenseits des Banketts, knapp
außerhalb des alten Bands (18,0 m), seine Vorderkante aber 2,6 m jenseits – 2,8 m tief in der Hülle. Das zweite
(`city_german_gruenderzeit`, 246 m) kommt mit R7a zurück: Fuß 16,6 m (Hülle 2,9 m), Vorderkante 1,2 m – 1,7 m tief in
der Hülle. Ursache: der Requisiten-Builder prüft nur den Fuß (siehe §2 „Fußabdruck“, `notes_for_next`).
"""
s = s.replace("PLATZHALTER_VERDECKUNG", occ)
open(p, "w", encoding="utf-8").write(s)
print("ok")
