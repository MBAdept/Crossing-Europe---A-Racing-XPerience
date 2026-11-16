## 3. Fairness

### 3.1 Volle Läufe (gemessen, 17:44, Last 10–11)

`godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` (161 s) und `modern_path_check.gd -- --full`
(62 s), Protokolle `pruefungen/sight_full.log`, `pruefungen/path_full.log`:

| Regel | Grenze (Vertrag D14, A-3) | gemessen | Reserve |
|---|---|---|---|
| F1 Kamera Mitte | 0 Fälle bis 270 m | 0 bis 270 m, erster Fall 280 m (99.424.500 Stichproben) | 10 m |
| F1 Außenspuren | 0 Fälle bis 260 m | 0 bis 260 m, erster Fall 270 m (326.680.500) | 10 m |
| F2 | ≤ 0,60 | 0,593 trocken, 0,596 Regen, 0,555 Schnee | 0,004 bei Regen |
| F3 | 0 später und im Anhalteweg | 0 von 5.923 (Fahrzeug und Schild); Fahrzeuge Arcade p50 510 m, Modern 534 m; Schilder 612 / 642 m | – |
| F7 | 0 Verstöße | 0 von 2.011.532 Querschnittsseiten | – |
| Modell | 0 Abweichungen | 0 von 394.011, Augpunkt höchstens 0,0002 px | – |
| Pfad | Abstand ≥ 250 m, Schleifen ≥ 2.000 m | 267,6 m (Bukarest–Sibiu km 57,8), Schleifen ab 2.064 m | 17,6 m / 64 m |

Alle Werte stimmen mit dem Vertrag und `docs/renderer-modern.md` §7.3 überein; die Grenzen sind im Code unverändert
(`F1_LIMIT_M` 270, `F1_LANES_LIMIT_M` 260, `F2_RATIO` 0,60). Die Reserven sind dünn: F2 bei Regen 0,004, F1 10 m – jede
Änderung an Kamera, Gelände oder Generator braucht den vollen Lauf (wie §7.6 sagt).

### 3.2 Was die Rechnungen nicht abdecken (eigene Beobachtung)

- **Nebel über der Ausblendung (F4/F5)**: Fahrzeuge (`vpbr`), Schilder (`sign`) und alle Requisiten (`baked`,
  `leaves`, `billboard`) bekommen den vollen Tiefennebel der Engine (Anteil t, linear 0,45 … 1,0 × Sichtweite) und
  Fahrzeuge/Schilder zusätzlich Arcades Ausblendung 1 − t² als Dither. Arcade färbt Sprites dagegen nur
  **multiplikativ** um (`RoadRenderer._modulate`, eingefroren: Modulationsfarbe = (1 − 0,7 t) × Licht + 0,7 t × 1,25 ×
  Nebelfarbe – ein dunkler Wagen bleibt dunkel) und blendet sie mit derselben Ausblendung in den Hintergrund. Der
  Kontrast eines Wagens gegen den Hintergrund ist damit in Modern etwa (1 − t)-mal so groß wie in Arcade: bei
  0,839 × Sichtweite (dort zählt die Simulation ihn als gesehen, t = 0,707) rund 30 %, bei 0,725 × Sichtweite rund
  50 % (abgeleitet aus den Mischformeln, nicht gemessen). Gelände und Fernboden haben seit RINT-B
  Arcades Gesetz (`FOG` mit 0,7 × t in `terrain.gdshader`), Requisiten und Fahrzeuge nicht: deshalb stehen ferne Bäume
  als graublaue „Geisterbäume“ auf grünen Feldern (mit `--gfx-debug=cover` ohne Nebel sind es grüne Bäume –
  `details/crop_s1_far_nofog.jpg`, gemessen 129/137/145 gegen Arcade 26/37/19 an derselben Bildstelle).
  Die Pflicht-Render-Prüfung „Objekt an der Sichtgrenze unter 3 % Kontrast“ aus §4.9.2 gibt es noch nicht.
- **Verdeckung durch Requisiten/Bauten** prüft keine Rechnung (bekannt, §7.4).
- **F3 nur trocken bei Tag** (wie die Studie).
- **Schild unter dem Tacho**: an T3 (6 s) schiebt der Blick in die Kurve das Winkelschild der Außenseite unter den
  Tacho (`ab_mittel/T3_ab_01.jpg`); es war vorher lange sichtbar (F1) – nur eine Beobachtung.
