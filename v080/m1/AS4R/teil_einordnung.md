**Was der Spieler jetzt sieht (gemessen in den Bildern dieses Ordners, Wirkung gefolgert):**

- **Pylon:** Die Spuren sind frei; die Seile laufen als Halbfächer vom Kopf zur Deckkante neben dem Geländer, das Bein
  steht senkrecht. Aus dem Fahrersitz sieht man den Fächer fast in Längsrichtung – er wirkt schmaler als das
  Arcade-Bild (dort zeigt das Billboard die Seitenansicht), ist aber räumlich richtig. Kein Stufenwechsel mehr.
- **Fenster:** Bei Tag sind alle Scheiben einer Fassade gleich (Glas des Sprites), nachts leuchten dieselben Fenster
  wie in Arcade und fast so hell, etwas oranger (hellste Pixel (255,212,120) gegen (255,226,131)).
- **Fabrik:** nachts keine reinweißen Dreiecke mehr, das Shed-Glas liest sich als Verglasung. **Büroturm:** Lichter
  verstreut statt in Spalten, das Foyer ist kein weißes Band mehr. **Laden:** Schild mit Zeichen. **Kirche:** im
  Rennen so hell wie in Arcade. **Fachwerkportal:** bei 30–100 m wie das Sprite.

**Was noch nicht gut ist:**

- Die Scheiben sind etwa 10 Stufen heller als das gemalte Glas des Sprites (Tönung zum Himmel); bei 250 m wirken
  die Fenster von Block B leicht grau-lila, und Block B flimmert bei 120 m mit 1,0 % statt 0,1 % (Sprite 0,2 %) –
  klein, aber gemessen.
- Schaufenster (Laden, Block B) leuchten nachts als weiße, flache Flächen – das Licht des Sprites, aber ohne Auslage.
- Die Mühle flimmert mit bewegter Kamera 1,3–1,7× so stark wie das Sprite (unverändert; ein Umbau der Flügel half
  nicht).
- Das Fachwerkportal bleibt bei 400 m blasser als das Sprite (Kontrast 94 gegen 138): dünne Streben verlieren im
  Alpha-Test der kleinen Mip-Stufen Deckung – das ist mit Farbe nicht weiter zu holen.
- Der Pylon hat eine feste Höhe (88,8 m) und gerade Seile: auf Brücken mit 50 oder 120 m Pylonhöhe passt er nicht
  zu Arcade, in engen Bögen (R 449 m) endet ein Seil bis 1,4 m neben der Deckkante (gerechnet; Seitenstreifen, nicht
  Fahrbahn). Die eigentliche Lösung ist `props/bridge_pylon_bare` mit Seilen vom Renderer.
- Fähren und Hausboote stehen weiter auf der Wiese, bis R2 sie auslässt oder R5 Wasser hat.
- Unverändert: Rückseite des Hausboots, Rückgiebel der Kirche, Fähre aus der Nähe.

**Was fehlt:** Messungen auf echter Grafikkarte und auf dem Steam Deck; Wasser; Seile vom Renderer.
