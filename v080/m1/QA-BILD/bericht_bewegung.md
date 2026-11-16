## 4. Bewegung (Clips, 60 Bilder/s fest, Autopilot)

Aufnahmen mit dem Movie Maker (`--write-movie … --fixed-fps 60`, `--no-watchdog`, ohne `--gfx-sync`, d. h. mit
Arbeiter-Threads wie beim Spieler), Arcade und Modern aus demselben Startzustand, nebeneinander geschnitten ab dem
ersten Rennbild (Modern zeigt 15 Bilder lang das Ladebild):

| Clip | Inhalt | Datei |
|---|---|---|
| S1 Kiel–Hamburg ab km 2, 12 Uhr, Modern „Hoch“ | 13 s Autobahn, Überholen, Kurve mit Winkeln, Windräder | `clips/s1_ab_arcade_modern_hoch.mp4`, nur Modern 18 s: `clips/s1_modern_hoch_60fps.mp4` |
| T4 Saragossa–Pau km 198,8, 11 Uhr, „Mittel“ | 9,5 s enge Kurve (R ≈ 136 m), Blick in die Kurve, Schild „Tankstelle 5 km“ | `clips/t4_ab_arcade_modern_mittel.mp4` |
| N1 Hamburg–Hannover km 71, 22 Uhr, Schnee, „Mittel“ | Nacht, Abblendlicht, Rücklichter | `clips/n1_ab_arcade_modern_mittel.mp4` |

Einzelbilder (gemessen am Clip, `m1/QA-BILD/tools/seq.py`):
- Ferne Fahrbahn S1 (Bilder 300–307, 3-fach vergrößert): Striche und Randlinien laufen ruhig, kein Flimmern, keine
  Treppen; mittlere Bildänderung im fernen Band (Zeilen 290–360) von Bild zu Bild 4,1 (Median) / 8,3 (Maximum, beim
  Ausblenden von „LOS!“) – keine Ausreißer, die ein Aufpoppen anzeigen würden.
- Detailstufen: Gelber Sportwagen (Ersatzbild) 180–240, blauer Kombi (Modell) 860–926 beim Zurückfallen, Eichen
  334–344: kein sichtbarer Sprung.
- T4 (Bilder 150–300 in 30er-Schritten): Gelände ohne Löcher und Nähte, Talboden schließt; die Innenseite der Kurve ist
  bis auf Grasbüschel leer (Sichtkorridor, B8).
- Sichtbar in Bewegung: die graublauen „Geisterbäume“ am Horizont (B7) stehen in jedem Bild als blasse Flecken über
  den Feldern.
- Kosten der Aufnahme unter llvmpipe (Last 8–11, 2 Rasterthreads, „GPU render time“ des Movie Makers): S1 Arcade
  132 ms je Bild, Modern „Hoch“ 1.317 ms (10 ×); T4 Arcade 103 ms, Modern „Mittel“ 681 ms (6,6 ×) – gemessen, aber nur
  Software-Rasterung; über echte GPUs sagt das Verhältnis wenig (abgeleitet).
