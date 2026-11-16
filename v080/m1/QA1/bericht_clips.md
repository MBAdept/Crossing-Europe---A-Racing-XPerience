### 2.2 Drei A/B-Clips (je 30 s, nebeneinander mit HUD)

`tools/ab_clip.sh` (neu): Godots Movie Maker nimmt dieselbe Fahrt in beiden Modi mit festen 60 Bildern/s auf
(`--gfx-sync`, gleicher Seed), das Ladebild von Modern wird an seiner Deckfarbe erkannt und abgeschnitten (14 Bilder),
beide Aufnahmen enden nach derselben Spielzeit. Ergebnis: H.264, 2560 × 720 (zweimal 1280 × 720), 60 Bilder/s, ohne
Ton. **Gleichlauf geprüft**: die HUD-Uhren beider Hälften zeigen in jedem herausgezogenen Bild dieselbe Zeit
(0:00.00 im Countdown, 0:01.50, 0:10.00, 0:12.00, 0:20.00, 0:25.00, 0:29.00). Modern jeweils mit „Hoch“.

| Clip | Inhalt | Größe | Aufnahme (gemessen) |
|---|---|---|---|
| `clips/kiel_hamburg_start_tag.mp4` | Kiel – Hamburg ab km 0, 12 Uhr: Countdown, Start, Autobahn bis km 10,5 | 21,1 MB | Arcade 160 s, Modern 1 217 s |
| `clips/dev_km48_nacht_21uhr.mp4` | dev_testetappe ab km 48, 21 Uhr: Tunnel, Nacht mit Mond, Verkehr, Kurven | 16 MB | Arcade 236 s, Modern 918 s |
| `clips/n2_dortmund_frankfurt_regen.mp4` | Dortmund – Frankfurt ab km 121, Regen, 16 Uhr: Verkehr, Radar- und Tankstellenhinweise | 23,1 MB | Arcade 257 s, Modern 1 720 s |

Was man sieht: Im Start-Clip fehlt in Modern das Spielerauto im Countdown und taucht nach „LOS!“ zu groß auf
(QA1-B1); danach laufen beide gleich. Nachts: Tunnel gleichwertig, draußen Mond, Bäume und Verkehr wie Arcade, Bäume in
Modern heller angestrahlt. Regen: in Arcade fallen Regenstriche, in Modern nicht (R4 fehlt) – die Fahrbahn ist in
Modern dunkler; Gran Turismo, Transporter und Sportwagen sind in beiden Modi Arcade-Bilder. Die Beschriftung der Hälften
liegt in diesen drei Clips über der HUD-Uhr (lesbar); `ab_clip.sh` setzt sie seitdem in einen Streifen über dem Bild.
Angesehen habe ich je Clip vier Einzelbilder (Start 1/4,5/15/28 s, Nacht 2/10/20/29 s, Regen 2/12/22/29 s);
Bewegung (Flimmern, LOD-Wechsel) lässt sich daran nicht beurteilen – das beurteilt der Mensch am ganzen Clip.
