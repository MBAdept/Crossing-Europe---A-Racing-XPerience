## 7. Im Rennen (`tools/ab_shot.sh`, Arcade | Modern aus demselben Simulationszustand)

Seed 11, Limousine, Autopilot, fliegender Start mit 50 km/h, Bilder 2 s und 4 s nach dem Start; Positionen aus der
Zählung (`census_all.log`, erste Kilometer der Innenstadt-Sets): Paris (Lüttich–Paris km 387,5: Haussmann, Eckhaus,
Loire-Haus, Lyoner Haus), Amsterdam (Bremen–Amsterdam km 357,3: Grachtenhäuser A und B, Reihenhäuser), Brüssel
(Köln–Brüssel km 195,5: belgische Reihe, Maashaus), Toulouse (Pau–Toulouse km 192,5: Lyoner Haus, Südhaus), Bern
(Lyon–Bern km 302,4: Lauben, Chalet). Je Stadt „Hoch“ 12 und 22 Uhr und „Mittel“ 19:30, Bern nur „Hoch“ 12 Uhr.

| Stadt | Voreinstellung | Uhrzeit | Exit | Fehlerzeilen (SCRIPT ERROR, Parse Error, ERROR:) in beiden Logs | Bild |
|---|---|---|---|---|---|
| Paris | hoch | 12 Uhr | 0 | 0 | `rennen_paris_hoch_mittag_00/01.jpg` |
| Paris | hoch | 22 Uhr | 0 | 0 | `rennen_paris_hoch_nacht_00/01.jpg` |
| Paris | mittel | 19:30 | 0 | 0 | `rennen_paris_mittel_daemmerung_00/01.jpg` |
| Amsterdam | hoch | 12 Uhr | 0 | 0 | `rennen_amsterdam_hoch_mittag_00/01.jpg` |
| Amsterdam | hoch | 22 Uhr | 0 | 0 | `rennen_amsterdam_hoch_nacht_00/01.jpg` |
| Amsterdam | mittel | 19:30 | 0 | 0 | `rennen_amsterdam_mittel_daemmerung_00/01.jpg` |
| Brüssel | hoch | 12 Uhr | 0 | 0 | `rennen_bruessel_hoch_mittag_00/01.jpg` |
| Brüssel | hoch | 22 Uhr | 0 | 0 | `rennen_bruessel_hoch_nacht_00/01.jpg` |
| Brüssel | mittel | 19:30 | 0 | 0 | `rennen_bruessel_mittel_daemmerung_00/01.jpg` |
| Toulouse | hoch | 12 Uhr | 0 | 0 | `rennen_toulouse_hoch_mittag_00/01.jpg` |
| Toulouse | hoch | 22 Uhr | 0 | 0 | `rennen_toulouse_hoch_nacht_00/01.jpg` |
| Toulouse | mittel | 19:30 | 0 | 0 | `rennen_toulouse_mittel_daemmerung_00/01.jpg` |
| Bern | hoch | 12 Uhr | 0 | 0 | `rennen_bern_hoch_mittag_00/01.jpg` |

13 Läufe, alle Exit 0, 0 Fehlerzeilen (gemessen). Ein Modern-Lauf mit zwei Bildern brauchte 4–8 min.

Angesehen:
- **Tag:** Wo Arcade die Straßenflanke eines Hauses als flache Bildfläche zeigt (Haussmann-Bogenläden in Paris,
  blinde Backsteinflanke des Treppengiebelhauses in Amsterdam, Erdgeschoss des Maashauses in Brüssel, Lauben in Bern),
  zeigt Modern Fenster mit Laibung und Sprossen, Läden mit Auslage, Gitter, Balkone und Blumenkästen. Front und Dach
  wie im Sprite; die Häuser stehen an derselben Stelle. Modern ist hier deutlich feiner, nicht nur anders.
- **Dämmerung (19:30, „Mittel“):** dieselben Fenster leuchten wie in Arcade, dazu die neuen Flankenfenster.
- **Nacht (22 Uhr):** Fensterlicht unregelmäßig wie in Arcade. Schwächer als Arcade sind die Schaufenster: In Paris
  ist die Ladenzeile rechts in Arcade eine Reihe heller gelber Bögen, in Modern beleuchtete Auslagen mit Waren, aber
  dunkler (beleuchtete Ladenpixel im Mittel 124 gegen 207 in Arcade, ein beleuchtetes Fenster 210; gemessen in der
  Nahansicht bzw. dem A/B-Bild) – der schwächste Punkt dieser Charge, Abschnitt 8.
- **Nicht meine Modelle:** In Toulouse stehen neben Südhaus und Lyoner Haus die spanischen Häuser als
  Arcade-Platzhalter (AS5b); in Brüssel fehlen in Modern die niedrigen Backsteinmauern, die Arcade am Straßenrand
  zeigt (Requisiten-Bauer/andere Sets, nicht untersucht).
