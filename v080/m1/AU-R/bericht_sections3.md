## 4. Hörproben (dieser Ordner)

Alle am Master-Bus des Spiels aufgenommen (Gesamtlautstärke 0,8 wie im Spiel voreingestellt), MP3 192 kbit/s; zu
jeder eine .txt mit Zeitmarken.

{HOERPROBEN_TABLE}

Die Zeitmarken sind Tonzeit: Unter Last läuft die Aufnahme ohne Bildschirm ein paar Prozent langsamer als das
Skript; die Marken sind darauf umgerechnet.

## 5. Abweichungen und offene Vertragsfragen

**Abweichungen vom Auftrag**
1. **R2 über fmix32 hinaus**: fmix32 allein trifft die Anteile nur im Mittel (Altstädte 0,34–0,90, 8 von 18 Ländern).
   Dazu kamen eine genaue Zuteilung je Altstadt (`cobbled_blocks`) und eine kalibrierte Schwelle je Land
   (`concrete_threshold` + Werkzeug `calibrate_concrete.gd`). Kommen Etappen dazu, muss das Werkzeug neu laufen
   (ein Test meldet einen geänderten Anteil).
2. **Klangfarbe aktiv gehalten**: Die neuen Schleifen (andere Seeds, andere Längen) wichen in den tiefen Terzen bis
   3,5 dB ab; sie sind an den gehörten Klang von AU-C1 angeglichen (`match_loop`, `heard`), die neuen Varianten von
   Glas, Kleinteilen und Lkw-Schlag ebenso (`match_spectrum`).
3. **Zwei Schichten gesenkt statt einer**: bei schweren Unfällen gegen Pkw der tiefe Schlag (−2,5 dB), gegen Lkw der
   Schlag des Aufbaus (−1 dB) – er ersetzt dort den tiefen Schlag und ist die lauteste Schicht.
4. **`tools/audio/qc/audio_qc.py`** geändert (Ogg für Schleifen in `vehicle/` zugelassen) – außerhalb der eigenen
   Dateien, aber nötig für die erlaubten Ogg-Schleifen.
5. **±10 ms** als 0–20 ms später umgesetzt (20 ms Stille vor jeder Schicht): ein früherer Einsatz als „jetzt“ geht
   nicht.
6. **Plattenabgleich**: Schwelle 6 ms statt „exakt“ – Godot meldet die Position in 64-Frame-Schritten.

**Offene Vertragsfragen**
1. **Beton-Wiederholung**: Der Grenzwert 0,40 (R1) passt nicht zu einem gewollten Takt (Platten alle 5 m); mit
   `slabs.db` 3 (Vorgabe: bleibt) misst Beton 0,65. Entweder gilt der Grenzwert dort ohne die Plattenschicht (0,11)
   oder die Platten werden leiser/unregelmäßiger (nächste Runde: `slabs.db` 3 → −3).
2. **Begrenzer bei 200 km/h auf Beton**: Die Plattenschläge liegen dort bei −2,7 dBFS, knapp unter der Obergrenze
   −2 dB; 12 Eingriffe je Minute bis 1,0 dB (R5 will ≤ 0,5 dB beim Reisen). Lösung ist derselbe Plattenpegel.
3. **Beton je Land**: Slowenien (5 Abschnitte), Litauen (3), Bulgarien und Lettland (je 1) können ±0,05 nicht
   erreichen – ihr nächster möglicher Anteil ist 0 oder mindestens 0,19.
4. **Unfall-Begrenzung ist eine Statistik**: Mit zufälligen Versätzen wächst die größte Begrenzung mit der Zahl der
   Unfälle; gemessen höchstens 2,4 dB in 24 Unfällen.

## 6. Für die nächste Runde (nicht in dieser)

- Plattenpegel `slabs.db` 3 → −3 (löst auch 5.1 und 5.2), Pflaster `surface_db` 19 → 12
- Glas in Körnern statt eines Rauschens, mehrere Stimmen beim Quietschen
- Leitplanke und Lkw-Schlag kürzer ausschwingen lassen, die Spitze des Reifenhohlraums, das Klacken auf kleinen
  Lautsprechern, die Mischung für Handgeräte
- alle Vorschläge zur Musikmischung (der Knopf `low_shelf_db` steht bereit, auf 0)
- `calibrate_concrete.gd` neu laufen lassen, wenn Etappen dazukommen

## 7. Ehrliches Urteil

{URTEIL}
