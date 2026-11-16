## 6. Geprüft und in Ordnung

- Gleicher Simulationszustand in beiden Modi an allen 14 Positionen (HUD-Zeit, km, Tempo, Tank identisch) – das
  A/B-Werkzeug zeigt wirklich dieselbe Lage.
- `--shot-fast` mit 1,0 s Vorlauf liefert für Modern dieselben Bilder wie ohne (S2: 0 bzw. 3 Pixel verschieden).
- Kamera: Fahrbahn, Linien und Fahrzeuge liegen an Arcades Stellen auf Geraden; Blick in die Kurve ruhig, Spielerauto
  höchstens ≈ 110 px aus der Mitte (T3/T4, innerhalb D12).
- Verkehr: Modelle (Limousine, Schrägheck, Kombi) sitzen auf der Fahrbahn, Räder am Boden, LOD0 nahe der
  Kamera scharf (besser als Arcades vergrößerte Sprites, `details/crop_s4_cars.jpg`); Ersatzbilder (Kombi, Sportwagen,
  Gran Turismo als Spieler; Sportwagen, Lieferwagen, Bus im Verkehr; Stadtbäume) sehen aus wie in Arcade.
- Schilder lesbar, gleiche Größe und Lage wie Arcade, Pfosten stehen im Boden (`details/crop_s1_sign.jpg`, T4
  „Tankstelle 5 km“).
- Tageszeiten 6 Uhr und 19:30 gleichwertig, 22 Uhr lesbar mit Abblendlicht und Rücklichtschein; Laternenschein in C1.
- Lack mittags innerhalb 10 % gegen das Cycles-Sprite (gemessen, S1 und S3).
- Steam Deck 1280 × 800: Modern füllt 16:10, HUD in den Ecken.
- OpenGL ES gegen OpenGL: max. 2/255, PSNR 71,8 / 88,0 dB.
- Rückfall: `--gfx-debug=fail` → Arcade mit der Meldung im HUD.
- Bewegung (Clip S1 „Hoch“, 60 Bilder/s fest, Einzelbilder 180–240, 300–307, 334–344, 860–926): keine flimmernden
  Linien oder Striche, keine sichtbaren Sprünge beim Wechsel der Detailstufen von Bäumen und Autos, keine Löcher im
  Gelände; mit `--gfx-debug=cover` kein Magenta unter dem Horizont an S1.
- Fairness F1–F3, F7 und Pfad: alle Grenzen eingehalten, Zahlen wie im Vertrag (Abschnitt 3).
- Logs aller Läufe (A/B, Clips, Fahrten, Prüfungen): keine „Too many instances“-Ablehnung, kein SCRIPT/SHADER ERROR.
  „ObjectDB instances were leaked at exit“ nur nach hartem Ende (`--quit-after`, Ende der Aufnahmen) und in Arcade und
  Modern gleich (25/25, 3/3) – nichts Modern-Eigenes.
- `ERGEBNIS` der ganzen Etappe Kiel–Hamburg unter Xvfb: Niedrig und Mittel gegen Arcade 28 Schlüssel, nur `gfx` anders.
- Render-Prüfungen der Bildlinse grün (Abschnitt 7), Arcade-Golden 20 von 20.
