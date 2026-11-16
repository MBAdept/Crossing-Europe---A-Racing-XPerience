## Modelle und Budgets (gemessen: `validate_models.py --report`, `model.json`, Export-Bericht)

| Modell | Kategorie (Budget Dreiecke / Aufrufe) | Dreiecke je Stufe | Aufrufe | Netze | Texturen | Atlas | px/m* | Export**** |
|---|---|---|---|---|---|---|---|---|
| `house_med` | Land (2 000 / 2) | lod0 1 343 · lod1 761 | 2/2 | 27,8 kB | albedo 484 kB | 1024² | 59,9 | 79 s |
| `church` | Land (2 000 / 2) | lod0 1 731 · lod1 1 275 | 2/2 | 40,6 kB | albedo + emit 551 kB | 1024² | 30,0 | 124 s |
| `factory` | Land (2 000 / 2) | lod0 1 624 · lod1 1 108 | 2/2 | 34,0 kB | albedo + emit 659 kB | 1024² | 29,5 | 117 s |
| `windmill` (AS1b, Fenster) | Land (2 000 / 2) | lod0 1 928 | 2 | 29,7 kB | albedo 814 kB | 1024² | 31,2 | 52 s |
| `houseboat` | Land (2 000 / 2) | lod0 1 054 | 2 | 19,9 kB | albedo 211 kB | 1024×512 | 37,3 | 54 s |
| `ferry_ship` | Land (2 000 / 2) | lod0 1 449 | 2 | 24,4 kB | albedo + emit 458 kB | 1024² | 12,2** | 84 s |
| `building_shop` | Stadt (10 000 / 2) | lod0 1 085 · lod1 757 | 2/2 | 23,7 kB | albedo + emit 300 kB | 1024² | 44,2 | 76 s |
| `building_oldtown` | Stadt (10 000 / 2) | lod0 2 326 · lod1 1 574 | 2/2 | 46,6 kB | albedo + emit 504 kB | 1024² | 40,7 | 100 s |
| `building_block_a` | Stadt (10 000 / 2) | lod0 4 596 · lod1 3 156 | 2/2 | 82,2 kB | albedo 108 kB | 2048×1024 | 49,0 | 140 s |
| `building_block_b` | Stadt (10 000 / 2) | lod0 5 180 · lod1 3 476 | 2/2 | 89,3 kB | albedo 821 kB | 2048×1024 | 44,0 | 144 s |
| `building_tall` | Stadt (10 000 / 2) | lod0 2 485 · lod1 2 485 | 2/2 | 51,8 kB | albedo + emit 92 kB | 2048×1024 | 29,8 | 107 s |
| `bridge_lamp` | Möbel (1 500 / 1) | lod0 882 | 1 | 12,1 kB | – (vpbr) | – | – | 0,1 s |
| `bridge_pylon` | Mast (5 000 / 1) | lod0 520 · lod1 520 | 1/1 | 18,5 kB | albedo + emit 237 kB | 1024² | 29,9*** | 46 s |
| `bridge_truss_arch` | Möbel (1 500 / 1) | lod0 1 100 | 1 | 12,9 kB | albedo + emit 78 kB | 1024×512 | 28 (Bild) | 1,1 s |

\* Texeldichte der Wände zur Straße (Gewicht 1; Rückseiten und Dächer mit den Gewichten des Katalogs weniger).
\*\* Modellmaß: die Fähre steht im Spiel mit Maßstab 0,33–0,45 → 27–37 px je Bildschirm-Meter (gefolgert).
\*\*\* am Fuß (0–30,75 m), Mitte 17,9, Kopf 13,4 px/m.
\*\*\*\* Blender-Export mit Bake (Cycles, 2× Überabtastung, 16 Proben, Verdeckung 24 Proben) im erzwungenen zweiten
Lauf, `nice -n 19`, ein Prozess, zwei Render-Threads; der Godot-Bake braucht je Modell ≤ 0,05 s.
Netze 0,49 MB, Texturquellen 5,07 MB für alle 14 Modelle; Texturen im Rahmen: Land/Möbel/Mast ≤ 1024, Stadt ≤ 2048.
Emission jeweils halbe Größe des Albedo. Summe AS4: Netze 0,49 MB, Texturquellen 5,07 MB (gemessen); alle Modelle
des Manifests zusammen innerhalb der Gesamtgrenzen (Validator: `CHECK models OK`).

## Messungen

**Stufensprung** (gemessen, `prop_scene --mode=lods`, Spielkamera, gleicher Ausschnitt bei der Umschaltentfernung
60 m = Detailstufe „mittel“; `pop.py`: Anteil der Pixel, die sich um mehr als 24/255 ändern, und mittlere Farbe):

| Modell | vorher (Runde 2) | nachher | mittlere Farbe lod0 → lod1 nachher |
|---|---|---|---|
| `house_med` | 1,05 % | 0,91 % | (194,174,133) → (196,176,133) |
| `church` | 0,41 % | 0,36 % | (198,201,201) → (200,202,202) |
| `factory` | 0,00 % | 0,00 % | (153,154,155) → (153,154,155) |
| `building_shop` | 0,97 % | 0,68 % | (184,185,186) → (183,184,185) |
| `building_oldtown` | 1,84 % | 1,53 % | (216,168,144) → (217,168,143) |
| `building_block_a` | 5,72 % (8/255 dunkler) | 4,51 % | (185,181,158) → (184,180,157) |
| `building_block_b` | 6,36 % (8/255 dunkler) | 5,24 % | (158,127,117) → (157,126,116) |
| `building_tall` | 18,15 % | 0,00 % | (117,137,160) → gleich |
| `bridge_pylon` | 7,41 % (+22 % Fläche) | 3,16 % (+9 %) | (240,243,246) → (242,244,247) |

Die mittlere Farbe springt nirgends mehr um mehr als 2/255; was bei den Wohnblöcken bleibt, sind die Sprossenkreuze
(4,5 cm, bei 60 m 0,5 px), die in lod1 fehlen. Bei „hoch“ schaltet der Requisiten-Builder erst bei 120 m um (Sprosse
0,27 px), bei „niedrig“ bei 40 m (gefolgert aus `prop_lod0_m`). Jenseits von 200 m bleibt lod1 (keine Impostoren für
Gebäude – wie bei AS1b), also kein zweiter Sprung.

**Gitter und Seile** (gemessen in den Spielkamera-Bildern, gefolgert für Bewegung): das Fachwerk ist ein
mipmap-festes Ausschneidebild (Streben ≥ 2,5 Texel) und bleibt bis 400 m als Fachwerk lesbar; die Seile (Prismen,
0,28/0,34 m) sind bei 400 m 0,6 px breit – mit MSAA (mittel 2×, hoch 4×) eine durchgehende schwache Linie, bei
„niedrig“ (ohne MSAA) können sie flimmern (nicht gemessen: Software-Renderer, Standbilder).

**Nacht** (Kontaktbögen, Spielkamera): Fenster leuchten unregelmäßig nach dem Anteil `lit` des Sprite-Rasters
(Büroturm 300 von 840 Scheiben, gemessen); Kirchturm mit Flutlicht und beleuchteten Uhren (3); Fabrik mit kaltweißem
Hallenlicht, Oberlichtern und beleuchtetem Werkszeichen (Zahnrad, spiegelsymmetrisch); Fähre mit Kabinenfenstern, Bullaugen, Decklampen und
Positionslichtern; Laterne (3 Anker), Fachwerkportal (2 Anker), Pylon (Flugbefeuerung). Bei Tag leuchtet nichts
(Emission × `ce_night`; unbeleuchtete Lampen zeigen nur ihre halbe Leuchtfarbe als Glasfarbe).
