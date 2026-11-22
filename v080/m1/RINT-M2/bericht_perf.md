
### 4.1 Leistung neben der Basis `515dd51`

Dieselbe Autopilot-Fahrt (`run_stage.gd`, Xvfb, llvmpipe, Zeitraffer 40, Seed 7, 12 bzw. 15 Uhr) auf dem Endstand
(`b903797`, Arbeitsbaum zur Zeit des Laufs; `9b02f05` ändert danach nur den Vorlauf der Tankstelle – die Testetappe
lief mit genau diesem Stand) und auf einer Kopie der Basis. llvmpipe rechnet auf der CPU: Bildzeiten
um 0,7 s sind die Software-Rasterung, nicht das Spiel; verglichen wird das Verhältnis.

| Etappe, Voreinstellung | Bild Median Basis → neu | 95 % Basis → neu | Draw-Calls | Primitive | `script_ms` | längstes Einhängen |
|---|---|---|---|---|---|---|
| Kiel – Hamburg, Mittel | 658 → 741 ms (+13 %) | 879 → 1094 ms (+24 %) | 108 → 156 | 99 k → 182 k | 4,15 → 4,04 | 1,9 → 3,8 ms |
| Kiel – Hamburg, Deck | 652 → 726 ms (+11 %) | 874 → 1025 ms (+17 %) | 104 → 136 | 99 k → 182 k | 3,96 → 4,06 | 4,2 → 2,9 ms |
| Dresden – Leipzig (Ziel in der Stadt), Mittel | 644 → 661 ms (+3 %) | 886 → 1471 ms (+66 %) | 131 → 184 | 157 k → 224 k | 4,55 → 4,79 | 2,5 → 3,8 ms |
| Testetappe ganz, Deck (Zeitraffer 16, Seed 11; Notiz 8) | 618 → 549 ms (−11 %) | 797 → 743 ms | 98 → 105 | 94 k → 95 k | – | 4,2 → 6,8 ms |

Auf der Testetappe (Deck) braucht `collect()` eines ganzen Stücks im Hauptfaden (Pfad, Kontext, alle Bausteine)
höchstens 3,96 ms, im Mittel 1,96 ms – Basis 4,34 / 1,91 ms, Merge-Stand vor der Nacharbeit 6,16 / 2,16 ms.

- Mehr Geometrie durch die Inhalte dieser Montage (R4–R6: Tankstellen, Grenzen, Tore, Laternen, Brückenteile; AS5a:
  Stadtgebäude in 3D): Primitive +84 % auf Kiel – Hamburg, +43 % in Dresden – Leipzig; auf llvmpipe wächst die
  Bildzeit damit (gefolgert: Software-Rasterung skaliert mit Primitiven und Fläche). Alle Werte liegen unter den
  Budgets der Voreinstellungen (Deck 650 Draw-Calls / 450 k Primitive, Mittel 900 / 700 k).
- Die Skriptzeit je Bild ist gleich geblieben (4,0–4,8 ms); `collect()` der Bausteine in diesen Läufen höchstens
  1,34 ms (Tankstelle). Das längste Einhängen eines Stücks 3,8 ms auf Kiel – Hamburg, 6,8 ms auf der Testetappe
  (Budget „commit_ms“ 3,0 ms für Mittel/Deck – in der Basis mit 4,2 ms schon überschritten; einzelne Höchstwerte auf
  llvmpipe, nicht untersucht).
- Das 95-%-Quantil in Dresden – Leipzig steigt am stärksten (Zieleinfahrt mit AS5a-Stadthäusern); auf einer echten
  Grafikkarte nicht gemessen.
