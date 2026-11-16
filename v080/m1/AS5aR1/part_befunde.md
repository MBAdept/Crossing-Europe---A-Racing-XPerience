## Die Befunde der Kunstkritik – geprüft, behoben, abgelehnt

Jeden Befund habe ich zuerst selbst nachgestellt (Bilder `shots/vor`, Stand 63544b6: Nahansichten der Straßenflanke
bei 12 und 22 Uhr, Prüfstraße bei 50 km/h) oder seine Zahlen mit den zwei unabhängigen Messungen von AS5a1 und der
Kritik verglichen (dieselben Werkzeuge, dieselben Zahlen).

| Befund (Kritik) | Schwere | geprüft | Ergebnis | vorher → nachher (gemessen) |
|---|---|---|---|---|
| K2 Straßenflanken im Erdgeschoss blind (Fachwerkzeile, Turmhaus, Barock), Giebelzeile ganz | hoch | bestätigt; zusätzlich: beim Turmhaus ist die ganze Flanke samt Giebel fensterlos | **behoben** über `close3d` | Öffnungen an der Straßenflanke: Fachwerkzeile 0 → 4 (3 Fenster, Rundbogentür), Turmhaus 0 → 19 (EG 4 + Tür, Fachwerk 2 × 5, Giebel 4), Barock EG 0 → 5 (4 Rundbogenfenster, Tür), Giebelzeile 0 → 18 + Granitsockel + 6 Maueranker; Dreiecke lod0 6 913 → 7 084, 3 332 → 5 319, 4 539 → 4 938, 3 712 → 4 882 |
| K4 Erkerfenster gemalt, Konsole weiß wie Plastik | mittel | bestätigt | **behoben** (`_oriel`) | 8 Erkerfenster mit Futter 10 cm, Laibung, zwei Sprossen, Sohlbank; Konsole eigenes Material (Sandstein `#a98a74`, AO aus dem Bake) |
| K7 Geländer dichter in Mip 1–3, ab Mip 4 weg | mittel | bestätigt (`mipcov`/`mipband` auf den gelieferten Atlanten) | **behoben** (`cut_fill`) | Helligkeit des Geländerbands gegen Mip 0, Mip 1/2/3/4: Mietshaus −2,3/−4,2/−8,2/+14,4 → +0,8/+0,2/+0,4/−0,8; Gründerzeit −5,2/−8,4/−13,6/+18,0 → +1,1/+0,8/+2,3/−0,0 Luma; Bild `gelaender_vorher_nachher.jpg` |
| K5 Stufenwechsel 60 m (Fachwerk 32 %, nachts +9 %) | mittel | bestätigt | **teilweise** (Rahmenring `inner_frame`, schmalere Hölzer) | Fachwerkzeile 32,0 % / +4,7 % → 27,1 % / +3,2 % (12 Uhr), 23,8 % / +9,0 % → 18,7 % / +5,0 % (22 Uhr); nachts Turmhaus +5,7 → +3,5 %, Kontor +9,9 → +8,1 %, Speicher +4,4 → +3,6 %; die übrigen ±1 Punkt unverändert. Rest: Überblenden (R7) |
| K6 Flimmern der Hölzer 40–60 m, Giebelzeile lod1 | mittel | bestätigt | **nicht behoben** | Fachwerkzeile 1,1/1,4 → 1,2/1,4 % bei 40/60 m (Sprite 0,1 %), Turmhaus 1,0/1,0 → 1,5/1,4 % (mehr Fenster an der Flanke), Giebelzeile lod1 1,1/1,3 → 0,9/1,2 %; die schmaleren Hölzer helfen nicht – siehe Einordnung |
| K10 Gartenstufe Einfamilienhaus (lod1 85 % von lod0) | niedrig | bestätigt | **behoben, mit Preis** | lod1 2 526 → 1 406 Dreiecke; Stufenwechsel dafür 11,1 → 17,2 % der Pixel (nachts 9,4 → 11,5 %) – Hecken mit anderer Facettierung |
| K10 Foyer des Büroturms nachts flach | niedrig | bestätigt | **nicht behoben** (Abweichung) | Die Auslage ist für 2–3 m hohe Schaufenster gebaut; das Foyer ist 9,5 m hoch, eine Theke wäre 3 m hoch. 7 Platzierungen |
| K10 Texeldichte Kontor bei Maßstab 1,2 | niedrig | bestätigt (gerechnet) | **nicht behoben** (Abweichung) | Der 2048×1024-Atlas ist voll: mehr Dichte oben kostet unten; 4 Platzierungen |
| K10 Kran aus der Nähe flache Kästen | niedrig | bestätigt | kein Handlungsbedarf (wie Kritik) | steht 53–83 m vom Rand |
| K1 Kurvenkorridor nimmt Häuser weg | hoch | nicht nachgestellt (Renderer) | nicht mein Paket | Leitung / R2 (FIX-M2 B-01) |
| K3 Tönung der Vororte fehlt | mittel | Kontaktbogen neu (`toenungen.jpg`) | nicht mein Paket | R7: Instanzfarbe auf die gebackene Albedo |
| K8 sonnige Putzfassaden heller als Arcade | niedrig–mittel | nicht nachgemessen | bewusst nicht im Modell | R4 ändert gerade das Licht; ein `albedo_mul` jetzt würde doppelt korrigieren |
| K9 Dämmerung | niedrig | – | nicht mein Paket | R4 |
