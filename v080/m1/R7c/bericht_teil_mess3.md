### 3.3 Überblenden der Stufen (Leitentscheid 1)

**Render-Prüfung `tests/race3d/render/check_lod_band.gd`** (neu, läuft mit `tools/run_render_checks.sh modern`): ein
Modell steht still vor der stillstehenden Kamera, das Ende von lod0 wird in 0,5-m-Schritten durch seinen Abstand
geschoben (wie Heranfahren, ohne die Bewegung des Bildes); gemessen wird die größte Änderung zwischen zwei Schritten
(Anteil der Pixel des Modells, die sich um mehr als 40 Stufen ändern), hart (Bandbreite 0,01 m) gegen das Band des
Requisiten-Bausteins, und die Deckung im Band (Löcher).

| Fall | hart | mit Band | Deckung im Band |
|---|---|---|---|
| Barockhaus lod0 → lod1 bei 34 m, erster Lauf | 7,1 % | **9,3 %** (FEHLER) | −0,0 % |
| Barockhaus, nach der Korrektur des Schattendurchgangs (`6eaa7e0`) | 7,1 % | **0,6 %** (OK) | −0,0 % |
| Eiche lod1 → Fernbild bei 150 m | 36,6 % | 1,1 % | −0,0 % |

Der erste Lauf deckte einen Fehler auf: im Schattendurchgang entschied die Bandmitte, und die flache Hülle von lod1
beschattete die zurückliegenden Fenster von lod0, solange beide sich die Pixel teilten (Bild
`lod_mitte_vorher.jpg`: Fenster dunkel gesprenkelt). Jetzt wirft die feinere Stufe durch das ganze Band.

**Clips bei „Mittel“** (20 s, 30 Bilder/s, Arcade | Modern, `tools/ab_clip.sh`; Bild für Bild ausgewertet mit
`py/clipframes.py`: Anteil geänderter Pixel je Bild im oberen Bildteil, Spitzen gegen den Median der ±5 Nachbarbilder):

| Clip | Bilder | Änderung je Bild Median / p95 | größte Spitze über den Nachbarn (ohne Startbild) | angesehen |
|---|---|---|---|---|
| Paris-Einfahrt (Lüttich – Paris km 386,8 → 390, bis 147 km/h) | 645 | 9,1 / 24,0 % | +5,7 % (Bild 189 → 190: Baumkrone dicht vor der Kamera) | kein Stufensprung zu sehen |
| Nürnberg-Altstadt mit Fachwerk (Würzburg – Nürnberg km 101,6 → 104,5, bis 122 km/h), erste Aufnahme | 645 | 15,4 / 25,8 % | +2,6 % | kein Stufensprung zu sehen |
| dieselbe Fahrt auf dem Endstand `138c90f` (nach der Korrektur des Schattendurchgangs; ausgeliefert) | 645 | 15,4 / 25,8 % | +2,5 % (Bild 172 → 173: Bewegung) | kein Stufensprung zu sehen |

Zum Vergleich der harte Wechsel der Basis: 8–32 % der Pixel *eines Hauses* in einem Bild (AS5aR1/AS5aR2, im Bild
eines ganzen Hauses gemessen); in den Clips gibt es keine Spitze dieser Art mehr. Die Streifen der größten Spitzen
(`clip_*_spitze.jpg`) zeigen Bewegung, keinen Wechsel. Den Paris-Clip habe ich vor der Korrektur des Schattendurchgangs (`6eaa7e0`) aufgenommen und nicht wiederholt; einen
Clip der Basis an derselben Stelle habe ich aus Zeitgründen nicht aufgenommen.

### 3.4 Fenster in der Dämmerung (Leitentscheid 4)

Hamburg km 88,6 (Kontor, Giebelzeile), Mittel: um 19:30 leuchten in Modern jetzt etwa so viele Fenster wie in Arcade
(angesehen, `daemmerung_hamburg_1930.jpg`: Arcade | Basis | R7c); in der Basis etwa die Hälfte. Die Zählung warmer Pixel
taugt um 19:00 nicht (die tiefe Sonne färbt die Backsteinfassaden selbst warm). Um 22 Uhr unverändert gegenüber der Basis
(`ce_night` = 1): in Hamburg leuchten rechts weniger Fenster als in Arcade – das ist die Auswahl der Fenster im Modell
(FIX-RINT F-04, Asset-Pipeline), nicht das Gesetz über die Stunde.
