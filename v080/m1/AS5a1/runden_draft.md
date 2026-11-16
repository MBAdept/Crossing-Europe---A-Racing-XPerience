## Runden Bauen → Ansehen (Tag, Dämmerung, Nacht) → Beheben

Jede Runde: Export (Probe mit halbem Atlas, ab Runde 4 echt), Bake, Import, Manifest, dann Bilder in der
Spielkamera (12 / 19,5 / 22 Uhr, „hoch“, neben dem Arcade-Sprite), Nahansichten (vorn, schräg, Straßenseite,
Rückseite, Dach) und Stufenbilder.

| Runde | gesehen | behoben |
|---|---|---|
| 1 (german) | Hecke und Gartenbaum des Einfamilienhauses nach dem Dezimieren kristallin facettiert; gemalte Gauben- und Turmfenster nachts heller als die geschnittenen Scheiben daneben; Glas des Büroturms zu türkis (Sprite spiegelt grauen Himmel); Foyer des Büroturms nachts eine weiße Fläche; eine Abdeckplatte über mehreren Schornsteinen | `shade_smooth` + Dezimierung 0,35/0,4; alles Atlaslicht × 0,55 (Faktor der Scheiben); `albedo_mul` für das Glas (Modell 75/94/103 gegen Sprite 78/95/103 bei 100 m, gemessen); `shop_light` 0,35; eigene Abdeckung je Insel, dann ganz aus (die Generatorschornsteine haben Köpfe) |
| 2 (german_old, hanse) | dunkler, verrauschter Fleck auf gespiegelten Rückwänden (Wand hinter dem Erker: Texel, die nur von innen gesehen werden, waren voll verdeckt); weiße Streifen am Ortgang in lod1 (Dachschräge des Giebelprismas koplanar unter dem Dach); Rückwand-Wiederverwendung griff auch auf Kronen und Gesimse | zweiter Verdeckungslauf (100 m): eingeschlossene Texel nicht abdunkeln (Barock-Rückseite sauber); verdeckte Schrägen entfernen (Haus 4, Barock 28 Flächen); Wiederverwendung nur für Wandmaterialien des Logs |
| 3 (Budget, Stufen) | Speicher 12 170 / 10 482 Dreiecke (über 10 000); lod1 fast so teuer wie lod0, Laibungen bei 60 m und mehr unter einem Pixel | `n_arc` 4 (Bögen), flache lod1 (geschnittene Wand wieder flach, Laibungen/Türen/Lamellen nur lod0): Speicher 8 954 / 1 287, Fachwerkzeile 6 882 / 1 040 |
| 4 (Licht, Dichte) | Foyer des Büroturms an den Fasen (nicht geschnitten) nachts noch weiß; Kontor im Erdgeschoss 39,9 px/m, Obergeschosse 25,9 px/m (Probe); Sockel des Büroturms 17 px/m Modellmaß | `light_mul` (Licht je Material: Foyer 0,35); Kontor Obergeschosse 0,7, Dach 0,25, abgewandt 0,25; Büroturm `floors` bei 12 m (Turm 0,75) |
| 5 (echter Export) | NOCH |  |
