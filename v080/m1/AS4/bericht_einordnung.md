## Ehrliche Einordnung

**Gut**
- Haus, Kirche, Fabrik, Altstadthaus, Ladenhaus und die Wohnblöcke sehen aus wie ihre Sprites (Farben, Proportionen,
  Fensterraster, Markise, Treppengiebel, Sägezahndach, Schlot) und haben echte Tiefe: Laibungen 12–30 cm, Rahmen,
  Sprossen, Sohlbänke, Türen mit Füllungen und Stufen, Fensterläden, Rinnen und Fallrohre, Schallluken, Uhren.
- Nachts leuchten die Fenster unregelmäßig nach dem Anteil des Sprite-Rasters; Kirchturm (Flutlicht, Uhren), Fabrik
  (Hallenlicht, Oberlichter, Werkszeichen), Fähre (Kabinen, Bullaugen, Decklampen), Laterne und Portal (Lichtanker mit
  Lichtfleck). Bei Tag leuchtet nichts.
- Budgets mit Abstand eingehalten (Land höchstens 1 928 von 2 000, Stadt höchstens 5 180 von 10 000, Möbel 1 100 von
  1 500, Mast 520 von 5 000; zwei bzw. ein Aufruf). Stufenwechsel ohne Farbsprung (≤ 2/255, gemessen).
- Der Bauer `house` ist allgemein: AS5a/AS5b können ihn für die Stadthäuser nutzen (Wände aus `props_cities`).

**Noch nicht gut**
- **Fähre – das schwächste Modell.** Kabinenfenster und Bullaugen sind gemalt (12,2 px/m im Modellmaß, im Spiel durch
  den Maßstab 0,33–0,45 gut 27 px/m), die Aufbauten sind flache Kästen; das Budget „Landgebäude“ (2 000 Dreiecke)
  reicht für ein 182-m-Schiff nicht zu mehr. Im Rennen steht sie 60–100 m entfernt und wirkt dort wie das Sprite.
- **Pylon:** feste Höhe des Sprites (Arcade passt die Höhe der Brücke an); Kopf 13,4 px/m; die Seile (0,34 m) sind
  jenseits von etwa 240 m dünner als ein Pixel (bei „niedrig“ mit 75 % Auflösung ab 180 m, gefolgert aus 711 px
  Brennweite) – mit MSAA bleiben sie eine schwache Linie, bei „niedrig“ (ohne MSAA) können sie flimmern.
- **Sprossenkreuze** verschwinden beim Stufenwechsel (Wohnblöcke 4,5–5,2 % der Pixel bei 60 m); bei „hoch“ erst bei
  120 m, wo sie 0,27 px breit sind.
- Rückseiten haben ein Viertel der Dichte – das gemalte Fenster im Rückgiebel der Kirche ist unscharf, wenn man
  zurückschaut.
- In den Prüfbildern (Kontaktbogen, `prop_scene`) überstrahlen helle Putzwände (Kirche #e8e1d0 erscheint 255/255/255,
  das Sprite bei etwa 203) – im Renn-Bild (A/B) nicht; Licht der Prüfwerkzeuge, nicht der Albedo (gefolgert).

**Fehlt**
- Wasser unter Hausboot und Fähre (R5); Vordächer und Schornsteine, wo die Sprite-Entwürfe keine haben.
- Messungen auf echter Grafikkarte und auf dem Steam Deck (alles hier: Software-OpenGL; Leistung gefolgert).
- Bewegtbilder zum Flimmern (nur Standbilder ausgewertet).
