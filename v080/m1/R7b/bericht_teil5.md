
## 5. Bilder und Urteil (LOOK, ehrlich gegen Arcade)

Alle Bilder „Details: Hoch“, 1280 × 720, llvmpipe unter Xvfb, `--seed=11`, Autopilot; links Arcade, rechts Modern.

**Bögen der zehn Stadteinfahrten** (`boegen/<stadt>.jpg`: 12:00, 19:30, 22:00 übereinander; je Bild
`ab/<stadt>_<zeit>_ab_00.jpg`). Startpunkt jeweils so, dass das erste Wahrzeichen der Stadt etwa 600 m voraus liegt.

| Stadt | Wahrzeichen (Darstellung) | Urteil |
|---|---|---|
| Hamburg | Elbphilharmonie (Bild), Michel (Modell) | Beide an Arcades Stelle (Render-Prüfung: 18 px Versatz). Tag gleich, Dämmerung gleich. **Elbphilharmonie nachts** (offener Punkt): Lichtebene des Sprites wie Arcade, das blau-weiße Fenstermuster und der warm beleuchtete Sockel stehen an derselben Stelle; in Modern etwas heller als in Arcade (das Bild wird wie die Vertretungen mit dem Licht einer mittelgrauen Fläche gerechnet). Clip: der Michel steht 20 s lang an Arcades Stelle, kein Springen, kein Raster. |
| Hannover | Neues Rathaus (3D-Kuppelkirche ohne Kreuz) | Bei 600 m in beiden Modi hinter Häusern; Nahbild siehe unten. |
| Leipzig | Völkerschlachtdenkmal (3D-Kuppelkirche ohne Kreuz) | wie Hannover: bei 600 m verdeckt; Nahbild (in der Kurve etwa 65 px neben Arcades Stelle, s. u.). Arcade zeichnet es selbst als Kuppelkirche – Modern folgt (kein eigenes Denkmal, das wäre AS6). |
| Dortmund | Florianturm (3D-Fernsehturm) | **Besser als Arcade bei Tag** (schlanker Turm mit Korb statt flacher Zeichnung, gleiche Stelle, gleiche Höhe). Nachts (Bild mit dem Endstand neu gerechnet): Fensterring warm, Schaft heller als in Arcade, rotes Flugwarnlicht an derselben Stelle – nach der Korrektur (erste Fassung: Leuchtpunkt füllte den Himmel, Prüfung „flugfeuer“) und einer Abschwächung **noch etwa dreimal so groß wie Arcades Punkt** (Schwäche). |
| Nürnberg | Kaiserburg (Bild) | Bei 600 m in beiden Modi hinter Fachwerkhäusern; Nahbild. Tag und Nacht ohne Unterschied am Horizont. |
| Paris | Eiffelturm (Bild), Sacré-Cœur (Skyline −30°) | Bei 600 m hinter Häusern; Clip und Nahbild. Die dunklen „X“ an einer Modern-Fassade rechts sind Geländer der Stadtgebäude (Probe mit und ohne Wahrzeichen-Knoten: 0 Pixel Unterschied) – kein R7b-Befund, Hinweis für AS5a/R7c. |
| Brüssel | Atomium (Bild), Basilika Koekelberg (Bild) | Beide an Arcades Stelle. In Modern sichtbar, in Arcade verdeckt: Arcades Häuserzeile davor (km 206,4, etwa x 550–760) fehlt in Modern – **ebenso auf der Basis** `9b02f05` (gemessen: `m1/R7b/basecmp/bruessel_12_base_ab_00.jpg`, Atomium und Koekelberg dort von `props.gd` an denselben Stellen), also kein R7b-Befund; Hinweis für die Stadtbauten (§9, Punkt 4). |
| Belgrad | Kirche des Heiligen Sava (3D-Kuppelkirche) | **Deutlich besser als vorher** (M2ZS1: „Belgrad schlechter“ – breites Ersatzbild): eine Kirche mit grünen Kuppeln an Arcades Stelle. Nachts angestrahlt wie Arcade (nach der Korrektur f0b30c7; vorher lag der Dunst über der Anstrahlung). Bei km 196,0 / 22 Uhr liegt sie in beiden Modi außerhalb des Bildes. Nahbild: etwa 85 px rechts von Arcades Stelle (Kurve, s. u.). |
| Calais | Leuchtturm (3D) | Bei 600 m verdeckt; Nahbild. Nachts: Feuer blitzt, vier Lichtstrahlen kreisen wie in Arcade. |
| Madrid | Cuatro Torres (3D-Hochhausgruppe) | **Besser als Arcade bei Tag** (fünf Glastürme mit Geschossbändern statt flacher Zeichnung). Nachts (mit dem Endstand neu gerechnet): Bürofenster auf grobem Raster wie Arcades Fenster, in der Ferne gemittelt (vorher flimmernd), rotes Flugwarnlicht oben. |

**Nahbilder** (`ab_nah/<stadt>_nah_<zeit>_ab_00.jpg`, Bogen `boegen/nah_prozedural.jpg`; etwa 250 m vor dem
Wahrzeichen, 12:00 und 22:00 – die sechs 3D-Formen und zwei Bilder):
- **Hannover** (Neues Rathaus, Kuppelform): an Arcades Stelle, Größe und Umriss wie Arcades Zeichnung (Kuppel mit
  Seitenkuppeln, Säulenfront); nachts angestrahlt mit warmem Schein um die Kuppel wie Arcade. Gleichwertig, in 3D
  plastischer.
- **Calais** (Leuchtturm): an Arcades Stelle, gleiche Höhe; nachts Laterne hell. Arcades Lichtstrahlen sind in diesem
  Bild als helle Streifen zu sehen, die kreisenden 3D-Strahlen stehen in diesem Augenblick quer zur Kamera und sind
  kaum zu sehen.
- **Nürnberg** (Kaiserburg, Bild) und **Paris** (Eiffelturm, Bild): pixelnah an Arcades Stelle, Tag und Nacht gleich
  (Burg warm angestrahlt, Turm golden).
- **Madrid** (Hochhausgruppe): 250 m sind zu nah – nur die Fußteile oben am Bildrand, in beiden Modi an derselben
  Stelle; nachts Bürofenster wie Arcade. Das Einfahrtsbild (600 m) zeigt die Türme ganz.
- **Dortmund** (Fernsehturm): bei km 228,5 in beiden Modi nicht im Bild (hinter Häusern) – das Einfahrtsbild zeigt ihn.
- **Leipzig** und **Belgrad** (Kuppelform) – **in Kurven sichtbar neben Arcades Stelle**: gemessen mit einer Sonde
  (`bilder/nah_kurve_leipzig_belgrad_sonde.jpg`: Arcade | Modern, darunter Modern nur mit den Wahrzeichen-Knoten):
  Leipzig bei 258 m etwa 65 px links von Arcades Zeichnung und die Kuppel etwa 35 px tiefer (die Kuppel steht
  25 m hinter der Front, Arcade zeichnet flach am Anker); Belgrad (Ada-Brücke, Kurve) bei 268 m etwa 85 px rechts und
  breiter, weil die Form mit der Straße gedreht ist und ihre Seitenwand zeigt. Ursache (gefolgert): echte Perspektive
  – 140–155 m Seitenabstand in einer Kurve verschieben die Tiefe, Arcade verschiebt nur seitlich. Auf gerader Anfahrt
  bei 600 m (Abnahme) 0,0 / 24,7 px; diese Nahbilder liegen außerhalb der Abnahme, aber über 5 %. Vorschlag in §9.

**Clips** (`clips/anfahrt_hamburg.mp4`, `clips/anfahrt_paris.mp4`, je 20 s, 960 × 540 je Seite):
- Hamburg (km 89,0 → 93,5): Michel und die Skyline stehen an Arcades Stelle; kein Springen, kein Raster beim
  Ein- und Ausblenden. Modern zeigt den Michel früher, wo Arcades Ladenbau höher gezeichnet ist.
- Paris (km 391,5 → Ziel): der Eiffelturm (Bild) steht bei km 393,1 (160 m voraus, nur die Beine im Bild) in beiden
  Modi an derselben Stelle am rechten Bildrand; davor in beiden hinter Bäumen, danach in beiden aus dem Bild. Die
  Skyline-Silhouetten am Ziel gleich. Kein Springen, kein Raster.

**Skyline und Horizont** (`ab/skyline_S1..S5_ab_00.jpg`, Kiel–Hamburg; `bilder/skyline_*`):
- S1–S5: unter der Horizontzeile liest der Fernboden als fernes Land (Grün bis zum Dunst), kein heller Streifen, kein
  Wandmuster – gleich wie Arcade. Am Ziel Hamburg (S5) stehen die grauen Stadt-Silhouetten in beiden Modi.
- Kassel (`bilder/skyline_kassel_nur_hintergrund.jpg`, nur der Hintergrund, 3D-Welt ausgeblendet): der Herkules als
  Arcades 2D-Zeichnung bei −24° (Azimut aus `cities.json`); nachts mit Licht (`…_22uhr_…`).
- Paris (`bilder/skyline_paris_nur_hintergrund.jpg`): Sacré-Cœur bei −30°, der Eiffelturm ausgeblendet, solange er
  auf der Straße in Reichweite steht (nie doppelt).

**Zoom-Bilder** (`bilder/*_tag_zoom_arcade_modern.png`): Belgrad, Dortmund, Madrid bei Tag, Ausschnitt um das
Wahrzeichen, Arcade oben, Modern unten. `bilder/kuppelkirche_durchscheinend_volle_deckung.png`: deckende und
durchscheinende Variante bei voller Deckung (pixelgleich).

**Gesamturteil**: Stelle und Gesetz wie Arcade; die vier prozeduralen Arten sind als 3D-Formen bei Tag besser als
Arcades flache Zeichnungen und als das alte Ersatzbild; die Bilder (32 Wahrzeichen mit Sprite) sehen aus wie in
Arcade, nur als flache Karte – erst AS6 bringt Modelle. Schwächer als Arcade: das rote Flugwarnlicht ist nachts etwa
dreimal so groß; die Elbphilharmonie nachts etwas heller; die Kuppelformen stehen aus der Nähe in Kurven bis etwa
85 px neben Arcades flacher Zeichnung. Fehlt: Modelle der Wahrzeichen (AS6). Die Stadteinfahrten zeigen das
Wahrzeichen bei 600 m oft gar nicht (verdeckt in beiden Modi) – darum die Nahbilder.
