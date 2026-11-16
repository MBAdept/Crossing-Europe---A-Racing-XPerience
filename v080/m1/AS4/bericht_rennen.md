## Renn-Look (A/B Arcade | Modern, `tools/ab_shot.sh`)

Drei Stellen, gefunden mit der Zählung über das ganze Netz (`census_all`) und der Lage je Etappe (`positions.gd`);
je Stelle „hoch“ und „mittel“, 12 Uhr und 19:30 (Dämmerung), je zwei Bilder (gemessen, Software-OpenGL):

| Stelle | Etappe, Start | sichtbar (AS4) | Modern-Lauf hoch / mittel |
|---|---|---|---|
| P1 | Kiel–Hamburg ab Kiel, km 75,8, 50 km/h, Bilder bei 1 s und 6 s | Haus, Altstadthäuser, Pylone der Köhlbrandbrücke, zwei Fähren | 506 / 514 s (12 Uhr), 483 / 360 s (19:30) |
| P2 | Kiel–Hamburg ab Kiel, km 82,9, Bilder bei 1 s und 5 s | Fachwerkportale der Elbbrücken (mit Lampen), Ladenhäuser | 360 / 373 s, 380 / 264 s |
| P3 | Bremen–Dortmund ab Dortmund, km 1,9, 100 km/h, Bilder bei 1 s und 3 s | Fabrik (links, gespiegelt), Wohnblöcke B | 281 / 176 s, 248 / 132 s |

Alle 12 Modern-Läufe (24 Bilder) ohne `SCRIPT ERROR`, `Parse Error` oder `SHADER ERROR` (gemessen, `ab_shot.sh`
prüft das Protokoll; `XDG_DATA_HOME` je Lauf unter dem Scratch-Ordner). P1 und P2 „hoch, 12 Uhr“ entstanden vor dem
Werkszeichen-Commit – die dort sichtbaren Modelle sind im Endstand byte-gleich. Befund: Die Modelle stehen dort, wo
Arcade seine Sprites zeichnet, in Größe und Farbe wie das Sprite; bei Dämmerung leuchten die Fenster der
Altstadthäuser und die Lampen der Portale. Gefunden und behoben: der gespiegelte Schriftzug der Fabrik (P3, siehe
Runde 3). Was sonst auffällt, gehört nicht zu AS4: Arcade zeichnet die seitlichen Fachwerkträger der Elbbrücken
(Brückenbauer R5) und die Hamburger Wahrzeichen im Hintergrund anders (Wahrzeichen-Pakete).
