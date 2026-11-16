## 5. Messungen (alle gemessen auf dieser VM, wenn nicht anders gesagt)

### 5.1 Prüfer, Budgets, Zeichenaufrufe, Bytes

`python3 tools/blender/validate_models.py --report` auf der Kopie → `CHECK models OK` (110 Modelle, 183 Sets, 128 mit
Modell; Netze 19,76 MB von 40 MB, Texturen 78,70 MB im Grafikspeicher von 240 MB; `logs/validate.log`). Bytes mit der
Rechnung von `tools/pck_report.py` (deflate -9 je Datei, `py/share.py`, `logs/share.log`):

| Modell | Platzierungen (Netz) | Dreiecke lod0 / lod1 | Klassen je Stufe | Atlas | Netze (Archiv) | Texturen PCK (Archiv) |
|---|---|---|---|---|---|---|
| `city_french_sud` | 588 | 5 359 / 3 716 (69 %) | vpbr + **baked_cutout** | 1024² RGBA | 118,9 kB | 1 573 kB (393,7 kB) |
| `city_belgian_terrace` | 315 | 2 586 / 1 162 | vpbr + baked | 2048×1024 | 46,4 kB | 1 748 kB (550,0 kB) |
| `city_french_maison` | 209 | 3 910 / 1 874 | vpbr + baked | 1024² | 90,0 kB | 874 kB (311,1 kB) |
| `city_french_immeuble` | 202 | 4 020 / 2 486 | vpbr + **baked_cutout** | 2048×1024 RGBA | 75,1 kB | 3 146 kB (566,4 kB) |
| `city_dutch_terrace` | 130 | 3 346 / 1 060 | vpbr + baked | 1024² | 73,0 kB | 874 kB (286,8 kB) |
| `city_belgian_stone` | 96 | 1 336 / 278 | vpbr + baked | 1024² | 20,7 kB | 874 kB (266,9 kB) |
| `city_paris_haussmann` | 55 | 6 518 / 3 714 (57 %) | vpbr + **baked_cutout** | 2048×1024 RGBA | 124,6 kB | 3 146 kB (600,8 kB) |
| `city_swiss_chalet` | 54 | 3 128 / 1 280 | vpbr + **baked_cutout** | 1024² RGBA | 55,6 kB | 1 573 kB (282,1 kB) |
| `city_dutch_canal` | 51 | 3 734 / 1 802 | vpbr + baked | 2048×1024 | 76,8 kB | 1 748 kB (631,4 kB) |
| `city_swiss_laube` | 46 | 4 865 / 942 | vpbr + baked | 2048×1024 | 69,5 kB | 1 748 kB (569,3 kB) |
| `city_dutch_canal_b` | 22 | 3 625 / 1 545 | vpbr + baked | 2048×1024 | 69,3 kB | 1 748 kB (682,8 kB) |
| `city_paris_corner` | 8 | 5 675 / 3 418 (60 %) | vpbr + **baked_cutout** | 2048×1024 RGBA | 111,9 kB | 3 146 kB (677,0 kB) |
| **Summe** | 1 776 | | | | **0,94 MB** | **22,2 MB im PCK (5,82 MB Archiv)** |

Alle zwölf ≤ 10 000 Dreiecke lod0 (größtes: Haussmann 6 518) und 2 Aufrufe je Stufe; Archivanteil 0,94 / 5,82 MB
unter der Grenze der Charge (3 / 7 MB). Das bestätigt AS5a2 (0,93 / 5,79 MB; das Eckhaus rechne ich mit 677 statt
653 kB Texturen – Rundung/Messweg, unerheblich). Backzeiten habe ich nicht nachgemessen (kein Neuexport in einer
Kritik); AS5a2 nennt 166–800 s je Modell.

Auffällig: **Fünf der zwölf Modelle (907 Platzierungen) sind als Ganzes `baked_cutout`** – Südhaus, Lyoner Haus,
Haussmann, Eckhaus, Chalet. Weil die Geländer eine Ausschneide-Klasse brauchen und die Grenze zwei Aufrufe je Stufe
ist, liegt die ganze Fassade in der Klasse mit `cull_disabled` und `discard` (`baked.gdshader`, `CE_CUTOUT`) – auch in
lod1, wo man die Geländer als gemaltes Band im deckenden Atlas zeigen könnte. Auf einer echten Grafikkarte kostet das
frühe Tiefentests und verdoppelt die gezeichneten Flächen (gefolgert, hier nicht messbar; Charge 1 hat dasselbe bei
Mietshaus und Gründerzeit). Das häufigste Modell (Südhaus, 588) spart in lod1 nur 31 % der Dreiecke.

### 5.2 Texeldichte (`texel_k5.gd`, lod0, Modellmaß, Außenwände je Richtung; `logs/texel*.log`)

| Modell | Straße unten (EG + 1. OG) | Straße oben | Anfahrt unten | Gegenseite (+x) | Bemerkung |
|---|---|---|---|---|---|
| Grachtenhäuser A | 49 (p10 50) | 40 | 48 | **15 / 12** | Gegenseite grob (zulässig: „reused walls on the far side“) |
| Grachtenhäuser B | 47 | 38 | 47 | **14 / 12** | dto. |
| niederl. Reihenhäuser | 46 | 46 | 45 | 46 / 14 | |
| belg. Reihenhäuser | 63 | 51 | 63 | 64 / 50 | |
| Maashaus | 54 | 44 | 54 | 55 / 44 | |
| Lyoner Haus | 65 | 59 | 71 | 65 / 52 | |
| Haussmann | 60 (p10 50) | 51 (p10 38) | 62 | 50 / 36 | |
| Eckhaus | 58 (p10 47) | 50 (p10 35) | 58 | **12 / 9** | Rückseite und Gegenseite blank (K8) |
| Lauben | 44 (p10 44) | 35 | 44 | 41 / 34 | im Spiel bei Maßstab 1,10: 39,7 |
| Chalet | 55 | – | 69 | 53 | |
| Südhaus | Hauswand 54, **Gartenmauer 15** | – | 45 (Mauer 16) | 53 | Mauer steht an der Straße |
| Loire-Haus | Hauswand 51, **Gartenmauer 14** | 51 | 43 (Mauer 15) | 49 | dto. |

Vertrag ≥ 26 px/m an Straßenwänden und Vorgabe ≥ 40 px/m im Erdgeschoss der Innenstadthäuser: **an den Hauswänden
erfüllt** (Lauben im größten Maßstab 39,7 – wie AS5a2 sagt). **Nicht erfüllt an den Gartenmauern** von Südhaus und
Loire-Haus: 14–16 px/m (AS5a2 schreibt „0,6 der Dichte“, das wären ≈ 32 px/m; gemessen sind es 0,28). Diese Mauern
stehen an der Straßenkante der Vororte, also näher an der Kamera als jede Hauswand dieser Sets – eine glatte,
weichgezeichnete Putzfläche.

### 5.3 Stufenwechsel (`--mode=lods`, Anker 20 m seitlich; `logs/lods/*.log`)

Anteil der Pixel mit Σ|ΔRGB| > 0,06 beim Wechsel lod0 → lod1, Helligkeitssprung:

| Modell | Mittel 60 m, 12 Uhr | Mittel 60 m, 22 Uhr | Hoch 120 m, 12 Uhr |
|---|---|---|---|
| Südhaus | 16,4 %, +0,1 % | 7,8 %, +1,3 % | 16,1 %, +0,1 % |
| Loire-Haus | 11,9 %, +0,6 % | 7,8 %, +1,9 % | 12,9 %, +0,4 % |
| Lyoner Haus | 14,6 %, +0,3 % | 10,0 %, +4,0 % | 13,9 %, −0,1 % |
| belg. Reihenhäuser | 16,4 %, +0,4 % | 12,4 %, +3,0 % | 16,9 %, −0,9 % |
| Maashaus | 16,2 %, −0,1 % | 11,8 %, +3,5 % | 19,9 %, −0,9 % |
| niederl. Reihenhäuser | 14,4 %, +0,6 % | 9,1 %, +3,0 % | 17,1 %, −0,1 % |
| Grachtenhäuser A | 18,3 %, −0,3 % | 14,5 %, +3,0 % | **22,6 %, −3,2 %** |
| Grachtenhäuser B | 17,5 %, −0,5 % | 13,3 %, +1,6 % | 21,6 %, −1,2 % |
| Chalet | 14,9 %, +0,6 % | 11,2 %, **+4,9 %** | 15,8 %, +0,8 % |
| Lauben | 9,1 %, +0,4 % | 9,0 %, **+4,9 %** | 9,7 %, +0,1 % |
| Haussmann | 14,2 %, +0,1 % | 11,8 %, +3,0 % (Farbton +45°) | 13,3 %, +0,1 % |
| Eckhaus | 13,3 %, +0,3 % | 11,0 %, +3,5 % | 12,7 %, +0,2 % |

Bestätigt AS5a2 (9–18 % bei 60 m). Nachts wird lod1 heller, weil die Scheiben ohne Laibung leuchten (lod1 hat beim
Maashaus und Lyoner Haus bei 60 m p90 der Fensterpixel 119 / 114 statt 80 / 80; `logs/lodcol_h22.log`). Auf „Hoch“
(Wechsel bei 120 m) tauschen die Grachtenhäuser fast ein Viertel der Pixel. Ein Arcade-Platzhalter wechselt nie.

### 5.4 Fernbild: die Fassaden werden mit der Entfernung heller und verlieren ihre Fenster (`k6_scene --mode=lodcol`)

Mittlere Helligkeit (Luma 0–255) und das dunkle Zehntel (p10 = Fenster) der Modellpixel bei 60 und 250 m, gleiche
Stufe, gleiches Renn-Licht (Hoch, 12 Uhr), daneben das Arcade-Sprite in derselben Lage (`logs/lodcol_h12.log`):

| Modell | Luma lod0 60 → 250 m | Sprite 60 → 250 m | p10 lod0 60 → 250 m | p10 Sprite 60 → 250 m | lod1 250 m gegen lod0 250 m |
|---|---|---|---|---|---|
| Haussmann | 134,8 → 148,9 (**+10,5 %**) | 111,9 → 109,6 (−2,1 %) | 55 → 77 (**+22**) | 42 → 53 (+11) | Luma −0,1, p10 +1 |
| Eckhaus | 144,8 → 154,6 (+6,8 %) | 120,8 → 119,2 (−1,3 %) | 66 → 83 (+17) | 44 → 59 (+15) | −0,8 |
| Grachtenhäuser A | 78,5 → 86,6 (+10,3 %) | 68,5 → 67,1 (−2,0 %) | 30 → 35 (+5) | 36 → 40 (+4) | −7,1 |
| Südhaus | 117,0 → 128,2 (+9,6 %) | 100,8 → 98,2 (−2,6 %) | 65 → 79 (+14) | 59 → 63 (+4) | −0,4 |
| Maashaus | 108,2 → 113,4 (+4,8 %) | 90,7 → 88,7 (−2,2 %) | 61 → 82 (**+21**) | 64 → 70 (+6) | −2,6 |
| Lauben | 106,1 → 111,3 (+4,9 %) | 92,0 → 89,0 (−3,3 %) | 56 → 79 (**+23**) | 56 → 58 (+2) | −0,6 |
| Lyoner Haus | 121,3 → 127,1 (+4,8 %) | 104,2 → 101,1 (−3,0 %) | 56 → 69 (+13) | 43 → 58 (+15) | −0,6 |
| niederl. Reihenhäuser | 90,3 → 95,2 (+5,4 %) | 82,5 → 82,1 (−0,5 %) | 45 → 63 (+18) | 43 → 54 (+11) | −0,8 |

Die absolute Helligkeit Modell gegen Sprite ist in der Prüfszene nicht zu vergleichen (der Platzhalter hat ein
eigenes Licht, KRITIK-5a1 K9); verglichen wird jeweils mit sich selbst. Ergebnis: Die Modelle werden zwischen 60 und
250 m um 5–10 % heller, das Sprite um 1–3 % dunkler (Dunst); das dunkle Zehntel – die Fenster – hellt beim Modell um
13–23 Stufen auf, beim Sprite um 2–15. lod0 und lod1 verhalten sich gleich (Unterschied ≤ 3 Stufen, Grachtenhäuser 7):
**es ist nicht die Stufe lod1, sondern die Mip-Kette des Atlas**, in der weiße Rahmen, Sohlbänke und Sprossen das
dunkle Glas überstimmen. Angesehen (Bild 29): die Fenster werden bei 200–350 m zu blassen rosa-lila Flecken (Südhaus,
Maashaus, Lyoner Haus, Lauben), das Sprite behält dunkle Fensterreihen. Das ist der Punkt „Scheiben ~10 Stufen heller,
grau-lila bei 250 m“ aus der Einordnung von AS4R – wiederholt.

### 5.5 Flimmern (`my_scene --mode=sparkcam`, Mittel, 12 Uhr, Viertelpixel-Schritte, Anteil kippender Pixel)

| Modell | 40 m | 60 m | 100 m (lod1) | 150 m (lod1) | Sprite 40 / 60 / 100 / 150 m | Kontrast 150 m Modell / Sprite |
|---|---|---|---|---|---|---|
| Haussmann | **1,0 %** | **1,2 %** | **1,0 %** | 0,6 % | 0,0 / 0,2 / 0,3 / 0,4 | 59 / 75 |
| Eckhaus | **1,1 %** | **1,2 %** | **1,0 %** | 0,7 % | 0,1 / 0,2 / 0,2 / 0,3 | 57 / 70 |
| Grachtenhäuser B | 0,7 % | **1,0 %** | 0,6 % | 0,9 % | 0,1 / 0,2 / 0,2 / 0,4 | 80 / 91 |
| Loire-Haus | 0,4 % | 0,5 % | **1,0 %** | **1,4 %** | 0,2 / 0,4 / 0,6 / 0,9 | 95 / 94 |
| Südhaus | 0,4 % | 0,4 % | 0,6 % | 0,8 % | 0,2 / 0,3 / 0,4 / 0,6 | 86 / 95 |
| Lauben | 0,3 % | 0,4 % | 0,3 % | 0,5 % | 0,1 / 0,1 / 0,2 / 0,3 | 81 / 97 |

Bestätigt AS5a2 (Haussmann identisch). Die Paris-Häuser flimmern bei 40–100 m 3–11× so stark wie ihr Sprite (bei 150 m 1,5–2,3×) – mehr als Block B,
den AS4R mit 1,0 % als Schwäche führte. Ursache: die Schmiedeeisen-Bänder und Fenstergitter (Alpha-Test, s. 5.6)
und Rahmen/Sprossen, 1–2 Pixel breit. Der Kontrast der fernen Fassade ist beim Modell geringer als beim Sprite
(dieselbe Blässe wie 5.4).

### 5.6 Geländer `baked_cutout` in den kleinen Mips (`py/mipcov.py`, `py/mipband.py`, Hintergrund Stein `#e4d9c2`)

| Atlas | Deckung (Anteil ≥ 0,5) gegen Mip 0: Mip 1 / 2 / 3 / 4 | Helligkeit des Bandes gegen Mip 0 (8-Bit-Luma) |
|---|---|---|
| Haussmann | 1,16 / 1,55 / 1,96 / **2,74** | −4 / −16 / −27 / **−53** |
| Eckhaus | 1,14 / 1,51 / 1,97 / 2,67 | −4 / −16 / −30 / −54 |
| Lyoner Haus | 1,16 / 1,77 / 2,24 / **4,15** | −3 / −21 / −32 / **−89** |
| Südhaus | 1,20 / 1,50 / 1,75 / 2,35 | −6 / −16 / −25 / −46 |
| Chalet | 1,00 / 1,17 / 1,48 / 1,85 | +0 / −13 / −36 / −65 |

Bei 150 Texeln je Meter (`CUT_PPM`) und 711 px Brennweite liegt Mip 3 ab etwa 38 m, Mip 4 ab etwa 76 m (gerechnet wie
KRITIK-5a1). Die Geländer verschwinden nicht mehr (der Fehler von Charge 1 vor `cut_fill`), sie **schließen sich**:
Ab 40 m wird aus dem durchbrochenen Schmiedeeisen ein doppelt so dichtes, ab 75 m ein fast geschlossenes dunkles Band.
AS5a2 meldet „±3 Stufen“ – mit einem dunklen Hintergrund gerechnet; vor hellem Stein ist das Band 27–89 Stufen
dunkler als nah. Die Auflage „coverage kept in small mips“ ist damit nicht erfüllt (Deckung 0,9–1,1 gefordert),
sichtbar als dunkle Querstreifen an den Haussmann-Fassaden bei 40–150 m und als Flimmern beim Übergang (5.5).

### 5.7 Umriss gegen das Sprite (`k4_scene --mode=outline2`, Sprite-Kamera −20°, 6°; Bild 26)

IoU lod0 / lod1: Grachtenhäuser A 0,999 / 0,999, Grachtenhäuser B 0,998 / 0,998, niederl. Reihenhäuser 0,997 / 0,997,
belg. Reihenhäuser 0,998 / 0,998, Maashaus 0,998 / 0,998, Loire-Haus 0,952 / 0,950, Südhaus 0,961 / 0,963, Lyoner
Haus 0,996 / 0,996, Haussmann 0,996 / 0,996, Eckhaus 0,997 / 0,997, Chalet 0,945 / 0,945, Lauben 0,997 / 0,997 –
**bestätigt AS5a2** (0,945–0,999; Abweichungen bei Bäumen und der Chalet-Traufe). Proportionen, Geschosse, Dachformen,
Giebel und Fensterraster sind die des Sprites.

### 5.8 Tönung (`tint_scene`, Bild 27)

`city_dutch_terrace` × `#ead6cc` trifft das getönte Sprite im Farbton (angesehen) – bestätigt. Bis R7 die Tönung
auf Modell-Instanzen legt, stehen die 50 getönten Reihen im Ruhrgebiet ungetönt (etwas röter) da.
