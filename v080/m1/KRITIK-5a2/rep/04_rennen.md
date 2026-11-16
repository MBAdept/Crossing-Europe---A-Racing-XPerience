## 4. Im Rennen (`tools/ab_shot.sh`, Arcade | Modern aus demselben Simulationszustand)

Seed 11, Limousine, Autopilot, Verkehr eingeschwungen, fliegender Start mit 50 km/h (der Autopilot beschleunigt auf
84–114 km/h), Bilder 2 s und 4 s nach dem Start; „Hoch“ wenn nicht anders gesagt. Alle 11 Läufe Exit 0, 0 Zeilen
`SCRIPT ERROR`/`Parse Error`/`ERROR:` in 22 Protokollen (gemessen); ein A/B-Lauf (Arcade + Modern, zwei Bilder) brauchte 4–8 min.
Der Stand enthält FIX-M2 **nicht** – in Kurven nimmt der Requisiten-Bauer deshalb noch ganze Häuser weg (F7 in
strenger Lesart, B-01); das sehe ich in Lyon und Bern (unten) und rechne es nicht den Modellen an.

| Bild | Ort | Zeit | Was man sieht (angesehen; Zahlen gemessen) |
|---|---|---|---|
| 01 | Paris (Lüttich – Paris km 387,5) | 12 Uhr | +2 s: Eckhaus voraus wie das Sprite, aber plastisch; +4 s: rechts die Haussmann-Flanke mit Bogenläden, Auslagen, Konsolen, Balkon und Gittern – Arcade schiebt dort eine verschwommene Bildfläche vorbei. **Klar feiner.** Sonnenseite heller als Arcade (Median-Luma 182 gegen 152) |
| 02 | Paris | 22 Uhr | Wohnfenster am Eckhaus gleich viele wie Arcade (4,0 / 4,0 % der Fassade), die Läden aber auf einem Drittel der Fläche und dunkler (8,9 / 24,4 %; warme Pixel rechts 149 gegen 203 Helligkeit) – **K1**. Die Fassade selbst ist im Mondlicht lesbar, Arcade zeigt dort Schwarz mit hellen Bögen |
| 03 | Amsterdam (Bremen – Amsterdam km 357,3) | 12 Uhr | Treppen-, Glocken-, Halsgiebel scharf, Flanke des Treppengiebelhauses mit Schiebefenstern (Arcade: blinde Backsteinflanke als Fläche), Stufen und Geländer am Kai. **Klar feiner** |
| 07 | Amsterdam | 22 Uhr | Fensterlicht wie Arcade (warme Pixel 1,65 / 1,67 % gegen 1,35 / 1,94 %), unregelmäßig und warm; die Giebel im Mondlicht lesbar – **gleichwertig bis besser** |
| 04 | Brüssel (Köln – Brüssel km 195,5) | 12 Uhr | Maashaus-Flanke mit Blausteinbändern und Kreuzstockfenstern links nah, Lütticher Reihe voraus. **Feiner.** Es fehlen in Modern die niedrigen Backsteinmauern, die Arcade am Straßenrand zeigt – das ist der `fence` „wall“ der Szenerie `city_belgian_outskirts`, den der Bauer `city` von R6 zeichnen wird (in diesem Stand fehlt er) – kein Modellfehler |
| 09 | Brüssel | 19:30, Mittel | einzelne Fenster warm erleuchtet wie Arcade, Fassaden im Abendlicht; gleiche Mauerlücke |
| 05 | Lyon (Montpellier – Lyon km 297,0) | 12 Uhr | +2 s: rechts fehlt in Modern das Lyoner Haus ganz (Kurvenkorridor, FIX-M2); +4 s: Lyoner Haus mit Quadern, Läden, Gittern, daneben AS4-Hochhaus. Fern (≈ 150 m) zeigen die Fenster der Flanke rosa-lila Flecken (**K2**) |
| 06 | Bern (Lyon – Bern km 302,3) | 12 Uhr | Lauben als echte Arkaden beidseits, Blumenkästen, Dachgauben; +2 s fehlt links eine Laube (Kurvenkorridor). **Das stärkste Bild der Charge** – eine glaubwürdige Berner Gasse |
| 08 | Bern | 22 Uhr | Fenster warm und unregelmäßig, einzelne Läden in den Lauben erleuchtet; insgesamt weniger Licht als Arcade (warme Pixel 1,5–2,0 % gegen 3,7–4,0 %), weil Arcade die Arkadenbögen hell zeigt (**K1**) |
{{RENNEN_VORORT}}

**Clip:** {{CLIP}}
