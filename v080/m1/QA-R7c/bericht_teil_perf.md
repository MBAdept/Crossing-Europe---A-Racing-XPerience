## 6. Leistung (gemessen, llvmpipe; Steam Deck und echte GPU gefolgert)

`tests/race/run_stage.gd` mit Autopilot, Seed 11, Limousine, 12 Uhr, `--timescale=20` (496 Bilder auf Kiel – Hamburg),
Xvfb 1280×800 für „Steam Deck“, 1280×720 für „Hoch“, gemeinsamer warmer Mesa-Cache (je Baum ein Aufwärmlauf verworfen),
abwechselnd R7c / 43a1fcc / Basis (`sh/perf.sh`, Logs `perf/`, Tabelle `sh/perfsum.py`). Neben mir liefen ein bis zwei
andere Agenten (Lärm in einzelnen Maxima, z. B. der unveränderte `bridge`-Haken 0,1 → 3,5 ms im selben Lauf).

| Lauf | Bildzeit Median / p95 | `render_ms` Mittel / Max | Stück bauen Max | **Einhängen Max** | **Haken `props` Mittel / Max** | Zeichenaufrufe* | Primitive* / Schatten |
|---|---|---|---|---|---|---|---|
| KH Deck R7c 1 | 801 / 995 ms | 3,16 / 9,5 | 25,2 | 2,80 | **0,27 / 4,44** | 132 | 136 993 / 8 364 |
| KH Deck R7c 2 | 748 / 871 ms | 2,92 / 13,1 | 23,7 | 2,32 | **0,25 / 3,82** | 132 | 136 993 / 8 364 |
| KH Deck 43a1fcc 1 | 775 / 968 ms | 3,04 / 8,3 | 112,3 | 1,80 | 0,10 / 0,59 | 129 | 158 344 / 8 364 |
| KH Deck 43a1fcc 2 | 780 / 939 ms | 2,79 / 11,4 | 23,0 | 1,88 | 0,10 / 0,47 | 129 | 158 344 / 8 364 |
| KH Deck Basis | 751 / 902 ms | 2,82 / 16,4 | 27,9 | 1,72 | 0,10 / 1,20 | 129 | 158 344 / 8 364 |
| WN Deck R7c | 804 / 993 ms | 3,56 / 13,6 | 13,4 | 2,40 | 0,32 / 1,82 | 151 | 174 509 / 8 448 |
| WN Deck 43a1fcc | 803 / 1023 ms | 3,34 / 20,1 | 25,3 | 3,52 | 0,10 / 0,75 | 144 | 192 079 / 8 448 |
| KH Hoch R7c | 971 / 1144 ms | 3,15 / 12,4 | 21,5 | 3,32 | 0,27 / 1,48 | **202** | 189 301 / 128 445 |
| KH Hoch 43a1fcc | 1089 / 1395 ms | 3,04 / 11,0 | 36,2 | 2,06 | 0,11 / 0,70 | 175 | 214 748 / 144 412 |

\* letztes Bild (Ziel in Hamburg). Alle Läufe Exit 0, 0 Fehlerzeilen; `ERGEBNIS` aller sieben KH-Läufe und beider
WN-Läufe identisch (Regel 3).

Urteil (gemessen): Bildzeit und `render_ms` gleich im Rahmen des Lärms; R7c spart 10–13 % Primitive (Hoch auch 11 % im
Schatten), kostet aber **+3 (Deck) bis +27 (Hoch, +15 %) Zeichenaufrufe** – im Band zeichnet ein Set beide Stufen, und
jedes Stück, dessen Instanzen ein Band überspannen, schaltet beide Knoten an – weit unter dem Budget (Deck 650, Hoch
1500). Der **Haken von `props.gd` kostet im Mittel 2,5–3× so viel (0,25–0,32 statt 0,10 ms) und hat auf Kiel – Hamburg
bei „Steam Deck“ in beiden Läufen Spitzen von 3,8–4,4 ms** (43a1fcc 0,5–0,6 ms, Basis 1,2 ms); Einhängen höchstens
2,3–3,3 ms (Budget Deck 3,0 / Hoch 4,0 ms, vorher 1,7–2,1 ms auf KH). Ursache (gelesen): `update()` rechnet alle 2 m für
**jedes** Stück den Kasten und die 8 Ecken; da der Schlüssel `span_key` auf 1 m gerundet ist, ändert er sich bei jedem
Schritt, und dann läuft die Schleife über **alle** Kindknoten aller Stücke (`_apply_lod`, props.gd 1206–1227). Bei
`--timescale=20` fällt das fast in jedes Bild; im echten Spiel bei 130 km/h etwa jedes dritte Bild (gefolgert).
