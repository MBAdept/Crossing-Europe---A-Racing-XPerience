## 5. Zahlen

### 5.1 Prüfer, Budget, Aufrufe, Bytes, Stufenentfernungen (gemessen)

`validate_models.py --report`: `46 Modelle, 182 Sets (51 mit Modell, 131 Platzhalter)`, `Netze 5.23 MB von 40 MB,
Texturen 37.37 MB im Grafikspeicher von 240 MB, Quellen 37.10 MB von 60 MB`, `CHECK models OK`.

| Modell | Dreiecke je Stufe (Manifest-Entfernung) | Aufrufe | Netze | Texturquellen |
|---|---|---|---|---|
| tree_oak / _b | 2465 / 887 · 2475 / 885 | 2 / 2 / 1 | 65 / 66 kB | 1906 / 1905 kB |
| tree_birch / _b | 2304 / 673 · 2400 / 723 | 2 / 2 / 1 | 54 / 56 kB | 1960 / 1961 kB |
| tree_beech / _b | 2471 / 888 · 2462 / 889 | 2 / 2 / 1 | 64 / 64 kB | 1939 / 1951 kB |
| tree_poplar / _b | 2470 / 888 · 2470 / 886 | 2 / 2 / 1 | 68 / 67 kB | 1911 / 1912 kB |
| tree_olive / _b | 2295 / 828 · 2190 / 791 | 2 / 2 / 1 | 59 / 56 kB | 2067 / 2064 kB |
| tree_pine / _b | 1693 / 592 · 1970 / 688 | 2 / 2 / 1 | 41 / 47 kB | 2103 / 2105 kB |
| tree_spruce / _b | 1062 / 462 · 858 / 378 | 2 / 2 / 1 | 57 / 46 kB | 1272 / 1267 kB |
| tree_cypress / _b | 1236 / 316 · 1236 / 316 | 2 / 2 / 1 | 40 / 40 kB | 1704 / 1694 kB |
| tree_palm / _b | 1184 / 714 · 1184 / 714 | 2 / 2 / 1 | 26 / 26 kB | 705 / 704 kB |
| bush_round / _b, bush_low | 396 / 111 · 396 / 117 · 395 / 115 | 1 / 1 | 12 kB | 435 kB je |
| heather | 390 / 118 | 1 / 1 | 13 kB | 445 kB |
| rock_a / rock_b / cliff | 640 / 960 / 4341 (auto) | 1 | 11 / 17 / 88 kB | 141 / 164 / 866 kB |

- Alle im Budget §4.6.9 (Baum ≤ 2 500 / 900, ≤ 450 Karten, 2/2/1; Busch/Heide ≤ 400 / 120, 1; Fels 1 500, Klippe
  6 000, 1). Fernbilder 92–256 × 180–512 px. Summe der 27 Modelle: Netze 1,14 MB, Texturquellen 35,6 MB (M9).
- Stufenentfernungen: im Manifest 60 / 200 m; der Props-Bauer nimmt die der Voreinstellung (Niedrig 40 / 120,
  Mittel und Steam Deck 60 / 200, Hoch 120 / 350 m) **je Chunk** (96 m) mit 6 m Hysterese (Code gelesen, M6).
- Zur Sprite-Kamera passen alle Größen (`object` = Sprite-Manifest, Prüfer).

### 5.2 Umriss gegen das Sprite (gemessen, orthografisch 6° wie die Sprite-Kamera, 24 px/m, ohne Boden)

| Art | lod0 außerhalb / Sprite gedeckt | lod1 | Fernbild | Variante `_b` | Überdeckung Grundart ↔ `_b` |
|---|---|---|---|---|---|
| Eiche | 2,0 % / 98,5 % | 0,9 / 94,0 | 3,5 / 98,2 | 9,1 / 83,5 | 0,77 |
| Birke | 3,9 / 96,3 | 1,6 / 90,2 | 4,4 / 96,4 | 18,8 / 79,8 | 0,68 |
| Buche | 0,8 / 98,3 | 0,3 / 93,4 | 0,9 / 97,4 | 7,7 / 92,0 | 0,85 |
| Pappel | 5,6 / 98,5 | 3,7 / 94,1 | 5,3 / 98,8 | 14,3 / 87,3 | 0,75 |
| Olive | 2,2 / 98,6 | 1,1 / 94,8 | 3,7 / 96,5 | 10,2 / 84,6 | 0,77 |
| Kiefer | 3,0 / 95,9 | 1,2 / 91,2 | 4,6 / 93,0 | 17,3 / 84,1 | 0,73 |
| Fichte | 9,0 / 88,9 | 5,8 / 86,9 | 7,9 / 87,3 | 10,0 / 77,4 | 0,74 |
| Zypresse | 0,8 / 96,5 | 0,8 / 94,6 | 0,9 / 96,4 | 0,9 / 73,7 | 0,75 |
| Palme | **20,0 / 69,3** | 18,4 / 65,4 | 20,1 / 65,9 | **57,1 / 38,5** | **0,31** |
| Busch rund / niedrig | 5,3 / 91,7 · 5,1 / 91,4 | 4,2 / 80,2 · 4,1 / 80,9 | – | 12,0 / 85,9 | 0,82 |
| Heide · Fels a · Fels b · Klippe | 0,4 / 87,2 · 0,5 / 90,2 · 0,0 / 94,0 · 1,0 / 99,5 | | | | |

Bild `04_umrisse_lod0_gegen_sprite.png`. Die Grundarten liegen im Sprite-Umriss (außer Palme); die Varianten sind
deutlich anders (Überdeckung 0,68–0,85, Buche am wenigsten), `palm_b` verlässt die Sprite-Form.

### 5.3 Stufen: Helligkeit, Sättigung, Kontrast (gemessen, `levels`, innere Pixel, Mittel)

Mittag, Sprung lod0 → lod1 in 60 m: Helligkeit −3,1 … +4,2 %, Sättigung ±3 %, Kontrast −8 … +20 % (Pappel +19,5 %).
lod1 → Fernbild in 200 m:

| Art | Mittag: Helligkeit / Sättigung / Kontrast | Dämmerung 19:30 | Nacht 23 Uhr (Helligkeit / Farbton) |
|---|---|---|---|
| Eiche | −3,0 / −8,8 / −32 % | −3,4 / −14,0 / −19 % | −1,2 % / +14° |
| Birke | +3,7 / **−19,2** / −38 % | +4,4 / −17,5 / −17 % | +8,7 % / +19° |
| Buche | +3,7 / −7,5 / −31 % | +2,9 / −11,4 / −12 % | +6,4 % / +11° |
| Pappel | −2,6 / −8,4 / −48 % | −4,4 / −13,9 / −36 % | −1,7 % / +12° |
| Olive | +2,2 / −14,9 / −44 % | +3,8 / −11,1 / −29 % | +3,5 % / +15° |
| Kiefer | +1,1 / −5,1 / −35 % | +1,2 / −7,1 / −20 % | +8,3 % / +2° |
| Fichte | **−8,2** / −17,7 / **−65 %** | +6,1 / **−33,6** / −66 % | **+25,7 %** / +14° |
| Zypresse | −2,0 / −5,2 / −48 % | +3,9 / −25,5 / +10 % | +19,4 % / +10° |
| Palme | −4,0 / +12,8 / −70 % (Farbton −16°) | −0,2 / −9,2 / −68 % | +10,0 % / −17° |

Arcade-Sprite gegen Fernbild am selben Ort, Mittag: Helligkeit −8,8 … +17,9 % (Palme: das Sprite ist heller), Kontrast
beim Sprite +14 … +290 % höher; Dämmerung: Sprite 10–22 % dunkler (Modern-Bäume abends heller, wie AS3 gemessen hat). Die
`_b`-Varianten liegen in denselben Bereichen (Rohdaten `logs/levels_h*.log`).

### 5.4 Flimmern (gemessen, `sparkle`: Anteil der Modellpixel, die bei ¼-Pixel-Verschiebung um > 20 % kippen)

| | 40 m | 80 m | 150 m |
|---|---|---|---|
| Eiche Modell / Sprite | 0,7 / 0,6 % | 1,6 / 1,1 | 2,8 / 2,0 |
| Birke | 1,2 / 1,6 | 3,1 / 3,1 | 6,0 / 5,4 |
| Pappel | 0,9 / 0,9 | 2,3 / 1,9 | 4,5 / 3,4 |
| Fichte | 1,8 / 1,1 | 2,9 / 2,1 | 5,0 / 3,8 |
| Kiefer | 1,9 / 1,9 | **6,1 / 3,7** | **10,5 / 7,5** |
| Palme | 4,1 / 5,5 | 10,5 / 8,4 | 13,9 / 12,4 |

Das Alpha-Laub kippt kaum mehr als das Sprite-Stand-in (Faktor 0,8–1,6); Kiefer und Fichte in 80–150 m am meisten.
Bewegt angesehen: siehe Abschnitt 4.

### 5.5 Was die Netze tragen (gemessen, `vertex_data.gd`)

- Wind `COLOR.r` steigt mit der Höhe (Eiche 0,17 → 0,86 in fünf Höhenbändern, Pappel 0 → 0,85); Palmwedel nach dem
  Abstand vom Ansatz (Spitzen 1,0); Steifheit Laub 0,55, Pappel 0,35, Fichte 0,70, Zypresse 0,75, Palme 0,15, Kern
  1,0; 45–51 Phasen je Laubbaum, Palme 12, **Zypresse 1**; Stämme `vpbr` ohne Wind; Fernbild ohne Wind (Shader).
- Normalen nach oben (y > 0,5): Laubbäume 28–38 %, Fichte 59–63 %, Palme 100 %, Heide 50–55 %, **Zypresse 0 %**.
- Stammfuß y −0,55 … −0,70 m, Fels a −0,51, Klippe −1,19, Büsche −0,09 … −0,31, Heide −0,17, `cover_grass` 0,00.
- Nichts leuchtet (Klassen `leaves`, `vpbr`, `baked`; keine Emission).
