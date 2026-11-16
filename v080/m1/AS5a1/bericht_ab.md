## Im Rennen: Arcade | Modern an drei Stadteinfahrten (`tools/ab_shot.sh`)

Dieselbe Simulation in beiden Modi (Seed 11, Limousine, Autopilot, Verkehr eingeschwungen, fliegender Start mit
50 km/h), Bild 2 s nach dem Start. Positionen aus der Zählung (`census_all.gd`): **Hamburg** (Kiel–Hamburg km 87,6:
Giebelzeilen, Kontor, Speicher, Kran), **Hannover** (Hamburg–Hannover km 141,7: Mietshäuser, Gründerzeithäuser,
Büroturm), **Würzburg** (Kassel–Würzburg km 201,7: Fachwerkzeilen, Turmhäuser, Barock).

| Datei | Ort | Voreinstellung | Uhrzeit | Ergebnis |
|---|---|---|---|---|
| `ab_hannover_hoch_mittag.jpg` | Hannover (Hamburg–Hannover km 141,7) | Hoch | 12 Uhr | beide Bilder da, 0 Skriptfehler |
| `ab_hannover_hoch_nacht.jpg` | Hannover (Hamburg–Hannover km 141,7) | Hoch | 22 Uhr | beide Bilder da, 0 Skriptfehler |
| `ab_hannover_mittel_daemmerung.jpg` | Hannover (Hamburg–Hannover km 141,7) | Mittel | 19:30 | beide Bilder da, 0 Skriptfehler |
| `ab_hamburg_hoch_mittag.jpg` | Hamburg (Kiel–Hamburg km 87,6) | Hoch | 12 Uhr | beide Bilder da, 0 Skriptfehler |
| `ab_hamburg_hoch_nacht.jpg` | Hamburg (Kiel–Hamburg km 87,6) | Hoch | 22 Uhr | beide Bilder da, 0 Skriptfehler |
| `ab_hamburg_mittel_daemmerung.jpg` | Hamburg (Kiel–Hamburg km 87,6) | Mittel | 19:30 | beide Bilder da, 0 Skriptfehler |
| `ab_wuerzburg_hoch_mittag.jpg` | Würzburg (Kassel–Würzburg km 201,7) | Hoch | 12 Uhr | beide Bilder da, 0 Skriptfehler |
| `ab_wuerzburg_hoch_nacht.jpg` | Würzburg (Kassel–Würzburg km 201,7) | Hoch | 22 Uhr | beide Bilder da, 0 Skriptfehler |
| `ab_wuerzburg_mittel_daemmerung.jpg` | Würzburg (Kassel–Würzburg km 201,7) | Mittel | 19:30 | beide Bilder da, 0 Skriptfehler |

**Abweichung vom Auftrag (gemessen, Zeit):** Ein Modern-Lauf mit „Hoch“ braucht auf der geteilten Maschine 6–8 min für
ein Bild (der erste Lauf mit zwei Bildern lief nach 600 s ins Zeitlimit). Statt 18 Läufen (3 Orte × 2 Voreinstellungen ×
3 Uhrzeiten) sind es 9: jeder Ort mit „Hoch“ zu 12 und 22 Uhr und mit „Mittel“ zur Dämmerung (19,5 Uhr) – an
jedem Ort kommen beide Voreinstellungen und alle drei Uhrzeiten vor, nur nicht jede Kombination.

**Was die Bilder zeigen (angesehen):** In Modern stehen an allen drei Einfahrten die Modelle dort, wo Arcade die Bilder
zeigt – gleiche Häuser, gleiche Lage, gleiche Höhe; die Fassaden sind schärfer, mit Tiefe und richtiger Perspektive
statt eines Bildes aus einem festen Blickwinkel. Nachts leuchten in Modern die Fenster und Schaufenster (Kontor mit
Auslage) wie in Arcade. In Hannover fehlt in Modern ein Mietshaus links (Arcade zeigt es etwa 35 m voraus): Die
Ausdehnung des Modells ist dieselbe wie die des Sprites (13,59 / 9,83 m gegen 13,61 / 9,85 m), die Kantenausrichtung
also gleich. Den Platz verwirft eine Ausschlussregel des Requisiten-Builders (`drop_reason`: Sichtkorridor einer Kurve
für dekorative Requisiten oder das Geländeband) – unabhängig davon, ob ein Modell oder ein Platzhalter dort steht
(gefolgert aus dem Code; welche der beiden Regeln, habe ich nicht gemessen). Laut Aufgabenliste beschränkt FIX-M2
(B-01) die Korridorregel auf Vegetation; nach dem Zusammenführen ist zu prüfen, ob das Haus dort steht.
Zur Dämmerung (19:30, Hamburg) leuchten in Modern deutlich weniger Fenster des Kontors als in Arcade, um 22 Uhr
etwa gleich viele: die Lichtrampe über die Uhrzeit ist Sache des Renderers (R4), die Fenster selbst sind dieselben.

**Fahrt durch die Würzburger Altstadt** (`fahrt_wuerzburg_altstadt.mp4`, `tools/ab_clip.sh`, Kassel–Würzburg
ab km 202,0, 12 Uhr, „Hoch“, 10 s, 60 Bilder/s fest, Arcade | Modern): 600 Bilder je Seite, 960×540 je Hälfte, 7,4 MB (gemessen; Modern-Lauf 2 176 s, Arcade 193 s). **Abweichung:** fliegender Start mit 50 km/h, aber der Autopilot beschleunigt trotz Tempo 50 auf 128 km/h (5 s) und bremst dann auf 60 km/h (9,5 s) – eine feste Geschwindigkeit bietet die Rennszene nicht, und ein zweiter Lauf (40 min) war nicht drin. Angesehen (Standbilder bei 1, 5 und 9,5 s in `fahrt_wuerzburg_altstadt_standbilder.jpg`): Fachwerkzeilen, Turmhäuser und Barockhäuser stehen beidseits wie in Arcade, mit Tiefe und richtiger Perspektive; kein Aufblitzen, kein Loch, keine fehlenden Häuser in den Bildern; ob das Umschalten der Stufen in Bewegung auffällt, ist im Film bei dieser Fahrt nicht sicher zu sehen (gefolgert: bei 60 m und 10–32 % Pixelwechsel möglich, siehe Messungen).
