## 4. Runden (bauen, ansehen, Mängel, beheben)

Proben mit halbem Atlas und einem Bake-Sample (`probe.py`, Schlüssel „debug“, nie committet), angesehen in der
Spielkamera mit Renn-Licht (`k5_scene --mode=close|dist2|lods`, „Hoch“, 12 und 22 Uhr). Danach Code eingefroren
(93e5031) und alle zwölf echt exportiert, Runde 4 auf den echten Exporten.

| Runde | Modelle | gefunden (angesehen/gemessen) | behoben mit |
|---|---|---|---|
| 0 | Südhaus | Unterseiten der dezimierten Platanenkrone als hellgraue Flecken (weniger als ein Texel: Gewicht `under` 0,05 × 0,3); das Balkongeländer belegte 40 % des (halben) Atlas | `weights.solid`; `rail_module` |
| 1 | Südhaus, belgische Reihe, Loire, Lyon | Krone sauber; die Flanken mit Fenstern lesen wie Fassaden; Lyon: 16 Fenster hinter den Fenstergittern blieben gemalt (Gitter 10–16 cm vor dem Glas gelten als Verdeckung); lod1 bei 250 m heller als das Sprite | `openings.cover_skip`; Helligkeit: im Rennen zu beurteilen (Prüfszene-Platzhalter 11–23 % zu dunkel, KRITIK-5a1) |
| 2 | übrige acht | Lauben: 33 Fenster gemalt (Geranien vor den Fenstern, Traufe über der obersten Reihe), Chalet 4 (Geranien), niederländische Reihe 8 (Traufe); Eckhaus: die schrägen Geländer der Ecke kosteten 39 % des Atlas (Dichte Obergeschosse 21 px/m), die Fenster der Ecke gemalt und ihre Raster in die Rückwand geschnitten; Chalet-Geranien facettiert | `cover_skip`; schräge Platten ins Modul; `openings.chamfer` + `_grid_faces`; `smooth`; Maashaus-Atlas 1024 × 1024 (77 px/m waren mehr als nötig); Haussmann-Gewichte Dach 0,35 / abgewandt 0,25 |
| 3 | Eckhaus, Lauben, Chalet, Reihe, Maashaus | Eckhaus 0 verdeckte Fenster, Dichte 40 px/m; Lauben noch 8 (Traufe) | `cover_skip` Dach/Untersicht der Lauben |
| 4 | alle zwölf, echte Exporte (Code 93e5031) | Prüfer rot: Grachtenhaus B `extent_m.left` 14,36 gegen Sprite 13,96 (das Kranzgesims der Flanke ragte hinten 0,4 m heraus); Eckhaus: Auslage der Ecke mit diagonalen Streifen; Maashaus: Kreuzstock dünner als im Sprite (4,5 statt 14 cm); im Rennen (Paris, A/B) Modern deutlich feiner, keine Blässe | Gesims endet 1 m vor der Rückwand; `_display_mat` liest auf der Ecke u = (x − y)/√2; `bar_w` 0,11 |
| 5 | alle 12 + Charge 1 + Brücken + Hausboot neu (Code 771b079) | Prüfer grün; Grachtenhaus B, Eckhaus, Maashaus geändert, alle übrigen byte-gleich | – |
