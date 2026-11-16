## 6. Leistung (gemessen auf dieser VM; Steam Deck und echte GPU abgeleitet)

### 6.1 Rechenzeit je Stück und beim Auftauchen eines Flusses (headless, Minimum aus 3 Läufen – lastfest nach A-11)

Eigenes Messskript `tests/qa_r5/bench_r5.gd` (Scratch-Kopie), Prüfling und Basis mit derselben Datei:

| Bau | Prüfling: collect / build (Worker) / commit (Hauptthread), Maximum je Stück | Basis |
|---|---|---|
| Gotthard, 6 Stücke ab dem Portal | 0,01 / **5,45** (Mittel 3,41) / **0,23** ms | 0,01 / 0,94 (0,62) / 0,11 ms |
| Somport | 0,01 / 4,47 (3,58) / 0,28 ms | 0,01 / 1,53 (0,94) / 0,15 ms |
| Köhlbrandbrücke | 0,18 / 4,78 / 0,49 ms | – (kein Brücken-Builder) |
| Elbbrücken (Fachwerk) | 0,06 / 6,11 / 0,59 ms | – |
| Ponte della Libertà (Damm, 20 Lampen) | 0,06 / **10,75** / 0,55 ms | – |
| Holtenau / Severin / Ludwigsbrücke / Ada | ≤ 0,15 / ≤ 3,95 / ≤ 0,44 ms | – |
| `far_ground.update_rivers()` im Bild, in dem der Fluss entsteht (Fluss, Fernufer, Fernland) | **0,77–1,62 ms** (7 Brücken) | – |

Lesart: der Hauptthread-Anteil (collect + commit) bleibt je Stück unter 0,8 ms – weit unter dem Budget „chunk commit
max 3 ms“ (deck/medium). Die Worker-Zeit steigt am Tunnel um den Faktor 5–6, an Brücken auf bis zu 10,8 ms; sie
verzögert nur das Eintreffen eines Stücks (3,4 km Vorlauf, abgeleitet unkritisch, auch mit den langsameren Kernen des
Steam Deck ≈ 1,5×). **R5s gemeldete Spitze „far_ground 69,9 ms“ ist als Rechenarbeit nicht nachstellbar** (höchstens
1,62 ms); sie war vermutlich Last der Nachbarn oder Knoten-/Material-Erstauftritt beim Zeichnen – auf echter Hardware
mit dem Leistungstest beobachten.

### 6.2 Etappenläufe im Steam-Deck-Profil (Xvfb 1280 × 800, `--gfx-preset=deck`, `tests/race/run_stage.gd`, Zeitraffer 4)

__PERFTABLE__

### 6.3 Steam Deck (Bilder, 1280 × 800, „deck“)

`deck_kb_rampe_00/01`, `deck_kb_nacht_00–02` (mit Basis), `deck_u1_innen_00/01`: Modern füllt das Bild, Arcade mit
Balken; Wasser mit Wellen, Seile, Pylonschatten auf dem Deck, Paneele und Gehwege in der Röhre sind auch in „deck“ da
(Regel 9: nichts Spielrelevantes wird ausgedünnt). Urteil wie in „Hoch“: Brücke gleich bis besser, Röhre besser.
Nachts am Köhlbrand gleich der Basis.
