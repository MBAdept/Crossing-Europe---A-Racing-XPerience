## 7. Was ich von den AS4-Angaben bestätige – und was nicht

| AS4 sagt | Prüfung | Ergebnis |
|---|---|---|
| Budgets eingehalten, Validator OK | `validate_models.py --report` auf der Kopie | **bestätigt** (gleiche Zahlen) |
| Wände zur Straße 29,5–59,9 px/m | `texel_probe.gd` | **bestätigt** für die Anfahrtsseiten; die **Seitenwand** der Fabrik zur Straße hat nur 18,7 px/m |
| Farbsprung beim Stufenwechsel ≤ 2/255 | `prop_scene --mode=lods`, Tag und Nacht | **bestätigt** (Helligkeit ≤ 1,1 %); der Pylon wechselt aber 58 % seiner Pixel (M5) – die 3,2 % von AS4 galten für einen anderen Ausschnitt |
| Modelle stehen im Rennen, wo Arcade die Sprites zeigt, gleich groß und farbig | eigene A/B-Bilder | **bestätigt** für die Gebäude; **nicht** für den Pylon: Arcade zeichnet ihn prozedural mit Seilen zur Deckkante, das Modell legt sie in die Fahrspuren (M1). Die AS4-Bilder (km 75,8, ≥ 120 m davor) zeigen das nicht |
| Bei Tag leuchtet nichts | Bildpixel, Netzdaten | **bestätigt** (Scheiben 0,21–0,27 Helligkeit); aber die Lampen-Scheiben sind bei Tag braun statt blau (M3) |
| Nachts leuchten die Fenster unregelmäßig wie im Sprite | Prüfbilder und Rennbild | **bestätigt**, aber matter als Arcade (M6); am Turm in Spalten (M8) |
| Fachwerk bis 400 m lesbar ohne Flimmern | Viertelpixel-Test, Film | **bestätigt** (flimmert weniger als das Sprite); bei 400 m blasser (M10) |
| Seile bei 400 m 0,6 px, bei „niedrig“ evtl. Flimmern | Viertelpixel-Test | Flimmern 0,8 % (Sprite 6,2 %) – **unkritisch**; das Problem der Seile ist ihre Lage, nicht ihre Stärke |
| Fähre schwächstes Modell | Prüfbilder | **teilweise**: auf Spielabstand (≥ 60 m, Maßstab 0,4) ist sie dem Sprite gleich; schwächer im Rennen ist der Pylon |
| Prüfwerkzeuge überstrahlen helle Putzwände, im Renn-A/B nicht | Renn-Look-Prüfszene (AS3) gegen A/B | **teilweise**: nicht ausgebrannt (Kirchenwand im Rennbild p95 229 < 255), aber 13 % heller als das Arcade-Sprite (203) und damit kalkweiß (M10, Bild 29); das Haus ist gleich hell |
