## 6. Leistung – ganze Etappe mit Autopilot, R7c gegen die Basis (gemessen)

Kiel – Hamburg, „Mittel“, 12 Uhr, Seed 11, Limousine, Zeitraffer 40, `tests/race/run_stage.gd` unter Xvfb
(`m1/R7c/stage.sh`; die Basis-Läufe mit meinen Dateien aus `43a1fcc`, sonst derselbe Stand). Zwei Runden abwechselnd
R7c / Basis (ein erster Lauf lief neben meiner eigenen Render-Nachprüfung und ist verworfen: 254 gegen 159 s).
Neben mir lief auf der VM ein Prüfjob eines anderen Pakets (4 Kerne).

| Wert (perf_stats) | R7c Runde 1 / 2 | Basis Runde 1 / 2 |
|---|---|---|
| Wandzeit der Etappe | 154 / 150 s | 153 / 149 s |
| Bildzeit Median / p95 (Zeitraffer 40, viele Physikschritte je Bild) | 541 / 812 – 544 / 786 ms | 549 / 779 – 532 / 790 ms |
| `render_ms` Mittel / Max | 3,81 / 10,5 – 3,83 / 9,7 ms | 3,59 / 9,6 – 3,73 / 13,0 ms |
| Stück bauen (Worker) Mittel / Max | 4,9 / 17,6 – 5,1 / 17,2 ms | 5,2 / 21,0 – 5,2 / 17,8 ms |
| Stück einhängen Max (Hauptfaden) | 1,77 – 1,71 ms | 1,88 – 1,60 ms |
| Haken `props` je Bild Mittel / Max (Hauptfaden) | 0,20 / 1,5 – 0,20 / 1,4 ms | 0,09 / 0,5 – 0,10 / 2,9 ms |
| `collect` der Requisiten Max | 0,04 ms | 0,04 ms |
| Zeichenaufrufe (letztes Bild) | 157 | 154 |
| Primitive / davon Schatten (letztes Bild) | 158 664 / 28 677 | 180 015 / 69 505 |
| Instanzen mit Instanz-Uniforms (Szene / Fahrzeuge Spitze) | 56 / 128 | 56 / 128 |

Urteil (gemessen): gleich schnell. Der Haken der Requisiten kostet je Bild 0,1 ms mehr (Abstand jedes Stufenknotens
zur Kamera, `_apply_lod`), weit unter dem Hauptfaden-Budget von 2 ms (A-18). Weniger Primitive, vor allem im Schatten
(−59 %); die Ursache habe ich nicht einzeln gemessen – gefolgert: ein Stück blendet jeden Stufenknoten aus, dessen
Band keine seiner Instanzen erreicht (euklidische Spanne der Instanz-Ursprünge), und lod0 endet bei den Stadthäusern
schon bei 35 m. Drei
Zeichenaufrufe mehr (Stufen im Übergang zeichnen beide). Die Zahlen von llvmpipe sagen über eine echte Grafikkarte
nur die Richtung (gefolgert).
