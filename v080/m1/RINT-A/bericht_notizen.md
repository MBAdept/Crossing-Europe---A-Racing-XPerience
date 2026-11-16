# Notizen für bericht.md (RINT-A)

Messwerte (gemessen, Last der Maschine 1–13):
- import: 1. Lauf hing (Hauptthread dreht, Arbeiter schlafen, 3 Texturen 0 Byte), 2. Lauf 8 s ok
- check_scripts: 287 / 0
- terrain_plan streng: 40 Pos., 601 Stücke, 37.488 Streifen, 0 Überlappungen, 0 Spitzenpaare (vorher 71 ≤ 1,83 m)
- modern_sight --full (145 s): F1 0 bis 270 m (99.424.500), F1 Spuren 0 bis 260 m, F2 0,593/0,596/0,555, F3 0/5923, F7 0/2.011.532, Modell 0
- props_render: props_spiegel 0,08 mittlere Abw., 0,04 % über 40; rotor 2837/2779 px Rotor, Turm 0/0
- light_base: tageslicht Asphalt −6,7 %, Gras +1,3 %, Himmel −4,8 %; schatten beleuchtet −0,09 % (94,1 % Boden), ganzer Boden −1,69 %
- Spiegelung (Auto-Ausschnitt S1, Hoch): Mittag beide 86/102/136, Sky 75/92/126, analytisch 83/96/122, neu 83,5/96,4/124,2;
  Abend beide 86/70/83, Sky 73,5/64/80, neu 83/68/79; Engine-Pfad neu = alt (0,000)
- Rauten: Fernbild-Knoten weg -> 555 px weg (y 300–319); Kontaktschatten weg -> 418 px (andere, y 318–401); nach Fix 438 px Fernbilder übrig (nahe Bäume)
- Bodendecker: T2 365 px, T4 2115 px geändert; test: 9 Pflanzen -> 18..27 Stücke
- Lecks beim Beenden: vorher Arcade 2/3, 2/4, 2/5 Läufe; nachher 0/6 Arcade, 0/3 Modern
- Horizontband S1: Arcade Gras (91,149,61) ab Zeile 322 bis Horizont, Modern Nebelband (197,219,237) Zeilen 324–329, Silhouetten 2 px tiefer
