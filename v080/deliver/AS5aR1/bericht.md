# AS5aR1 – Nacharbeit der Stadthäuser german, german_old und hanse nach der Kunstkritik (Bericht)

Paket **AS5aR1** von v0.8.0 „Modern“: Nacharbeit von AS5a1 nach der unabhängigen Kunstkritik KRITIK-5a1. Zweig
`worktree-wf_db8ba6cd-508-3`, gesichert als `origin/wip/v080-as5ar1`; Basis `63544b6` (AS5a1), Endstand `7153381`. Worktree `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-3`.

Zahlen sind **(gemessen)** – auf dieser VM, Software-OpenGL (llvmpipe) unter Xvfb, Prüfszene im Renn-Look
(`prop_scene`/`k4_scene`/`k5_scene` der Kritik, „Mittel“ für Stufen und Flimmern, „Hoch“ für Bilder) bzw. das Rennen
(`tools/ab_shot.sh`) – oder **(gerechnet/gefolgert)**. Alles über echte Grafikkarten, das Steam Deck oder die Wirkung
auf einen Menschen ist gefolgert.

## Kurzfassung

Der größte Mangel der Kritik ist behoben: Die Straßenflanken der Altstadt- und Giebelhäuser sind nicht mehr blind.
Fachwerkzeile, Fachwerkhaus mit Turm, Barockhaus und Giebelzeile haben an der Flanke zur Fahrbahn Fenster und Türen
im Stil ihrer Front (Hook `close3d` im Generator, das Sprite bleibt unverändert: 86/86 Sprite-Sets identisch), nachts
leuchten sie nach denselben Regeln wie die Front. Der Erker des Turmhauses hat echte Fenster mit Futter, Sprossen und
Sohlbank statt gemalter Rechtecke, seine Konsole ist Sandstein statt weißem Kegel. Geländer verschwinden nicht mehr
ab Mip 4: Die Lücken im Atlas tragen Alpha 0,4 und die Farbe des Hintergrunds, das Geländer wird in der Ferne zu einem
Band mit seiner mittleren Helligkeit (Abweichung je Mip-Stufe vorher bis 18 Luma-Stufen, jetzt höchstens 2,3). Ein
Rahmenring im gemalten Glas senkt den Helligkeitssprung beim Stufenwechsel nachts (Fachwerkzeile +9,0 → +5,0 %). Die
Gartenstufe des Einfamilienhauses hat 1 406 statt 2 526 Dreiecke.

Nicht behoben: das Flimmern der Fachwerkhölzer in Bewegung (unverändert 1,2–1,4 % gegen 0,1 % beim Sprite – die
schmaleren Hölzer haben nicht geholfen) und ein Stufenwechsel, der weiter 13–27 % der Pixel ändert; beides braucht
den Renderer (Überblenden, kürzere Umschaltentfernung je Modell). Renderer-Befunde der Kritik (Kurvenkorridor,
Tönung, Sonnenhelligkeit) sind nicht mein Paket und stehen unter „Für andere Pakete“.

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


## Was geändert ist (Dateien)

| Datei | Änderung | Zweck |
|---|---|---|
| `tools/blender/cesprites/props_cities.py` | Hooks, Voreinstellung = Sprite: `wallmat(..., inner_frame=0.0)`; `close3d` zusätzlich in `german_old_fachwerk_b`, `german_old_barock`, `hanse_gabled` und für die Erdgeschossflanke in `german_old_fachwerk` | Rahmenring im gemalten Glas (nur 3D); Fenster, Türen, Granitsockel und Maueranker an den Straßenflanken – kein Sprite-Vertex und kein Sprite-Material verändert (Geometrie-Gate inkl. Material-Hash) |
| `tools/blender/ce3d/cities3d.py` (eigenes Modul) | `_oriel`, `_cut_fill`, `_mat_mask`, `_lod1_decimated`, `timber_members(inset)`, `_log_walls(inner_frame)`, Doku der Optionen | Erkerfenster und Konsole, Geländer-Lückenfüllung, Gartenstufe, schmalere Hölzer, Rahmenring |
| `tools/blender/ce3d/catalog3d.py` (Block `# --- AS5a ---`) | `params={"close3d": True}` für Turmhaus, Barock, Giebelzeile; `timber.inset` 0,03; `oriel`; `cut_fill` für Mietshaus und Gründerzeithaus; `lod1_decimate` 0,5 für das Einfamilienhaus; `hga_anchm` als vpbr | die Katalogeinträge der elf Modelle |
| `assets/models/props/city_{german,german_old,hanse}_*` | alle elf neu exportiert und gebacken | – |
| `assets/models/manifest.json` | neu erzeugt (`export_models.py --manifest-only`) | – |
| `docs/modelle.md` | Abschnitt 20: Nacharbeit, Hook-Tabelle, Messungen, Einordnung; Statuszeile | – |
| `tests/golden/modern_slice.{md5,env}` | Prüfsummen von `modern_s4_mittel` und `modern_s5_niedrig` neu (dort stehen die Stadthäuser), nach Ansehen | – |

Gemeinsame Pipeline-Dateien (`core`, `glb`, `roles`, `bake`, `lod`, `manifest`, `export`, `export_models.py`,
`validate_models.py`, `tools/models/**`, `model_db.gd`) und `buildings3d.py` sind **nicht** geändert: Die acht
Hausmodelle von AS4 haben unveränderte Schlüssel und Dateien. Die Modelle, deren Schlüssel `props_cities.py` enthält
(`bridge_pylon`, `bridge_pylon_bare`, `bridge_truss_arch`, `bridge_lamp`, `houseboat`), habe ich neu exportiert und
gebacken – `git status` danach ohne Änderung: **byte-gleich** (gemessen).

## Budgets je Modell (Endstand, gemessen)

| Modell | Dreiecke lod0 / lod1 | Aufrufe je Stufe | Atlas | px/m Straße min–max | Rückseite | Netze B (Archiv) | Texturen PCK (Archiv) | Export s |
|---|---|---|---|---|---|---|---|---|
| `city_german_house` | 2962 / 1406 | 2/2 | 1024×1024 | 60.0–60.0 | 5 gespiegelt, 1 eigene | 81395 (80292) | 873944 (254478) | 208.68 |
| `city_german_old_fachwerk` | 7084 / 1050 | 2/2 | 2048×1024 | 34.15–42.69 | 19 gespiegelt, 5 eigene | 105084 (102051) | 1747768 (523614) | 767.77 |
| `city_german_old_fachwerk_b` | 5319 / 990 | 2/2 | 2048×1024 | 41.71–52.14 | 8 gespiegelt, 4 eigene | 79569 (77620) | 1747768 (432426) | 1004.95 |
| `city_german_mietshaus` | 2176 / 506 | 2/2 | 2048×1024 | 52.91–138.28 | 4 gespiegelt, 0 eigene | 34819 (33586) | 3145888 (489569) | 626.67 |
| `city_german_gruenderzeit` | 4410 / 2394 | 2/2 | 2048×1024 | 40.81–140.53 | 6 gespiegelt, 0 eigene | 78280 (76411) | 3145888 (558304) | 710.46 |
| `city_hanse_gabled` | 4882 / 1240 | 2/2 | 2048×1024 | 33.5–41.87 | 22 gespiegelt, 4 eigene | 82009 (80456) | 1747768 (672468) | 660.38 |
| `city_german_old_barock` | 4938 / 2401 | 2/2 | 2048×1024 | 37.79–47.23 | 11 gespiegelt, 4 eigene | 97382 (95271) | 1747768 (482118) | 714.02 |
| `city_hanse_speicher` | 8950 / 1283 | 2/2 | 2048×1024 | 29.83–42.62 | 33 gespiegelt, 11 eigene | 117875 (114183) | 1747768 (745230) | 652.31 |
| `city_german_office` | 427 / 203 | 2/2 | 2048×1024 | 15.92–21.23 | 2 gespiegelt, 0 eigene | 11980 (11020) | 1747768 (360457) | 172.48 |
| `city_hanse_kontor` | 9865 / 749 | 2/2 | 2048×1024 | 28.83–41.19 | 8 gespiegelt, 0 eigene | 113220 (108978) | 1747768 (729107) | 411.42 |
| `city_hanse_crane` | 1260 / 1052 | 2/2 | 1024×1024 | 90.0–90.0 | 3 gespiegelt, 1 eigene | 41091 (39384) | 873944 (116217) | 70.11 |


Spalten wie bei AS5a1: Dreiecke je Stufe (`model.json`); Zeichenaufrufe = Oberflächenklassen je Stufe; px/m Straße =
Texeldichte der Straßenwände aus dem Bake (Modellmaß, Minimum Obergeschosse, Maximum Erdgeschoss/1. OG);
Rückseite = abgewandte Wände mit den gespiegelten Texeln der Straßenwand; Bytes = Netze und importierte S3TC-Texturen
im PCK, in Klammern deflate -9 wie `tools/pck_report.py`; Export s = Bauen + Backen (CE_THREADS=3, ein Worker,
nice 19, Last 10–16). Summe: Netze 0,84 MB (Archiv **0,82 MB**), Texturen 20,27 MB im PCK (Archiv **5,36 MB**) –
Anteil der Charge höchstens 3 / 7 MB. Alle elf ≤ 10 000 Dreiecke in lod0 (größtes: Kontor 9 865), 2 Aufrufe je Stufe.
Fachwerkzeile 34–43 px/m statt 35–44 (die neuen Laibungen kosten Atlasfläche).

## Messungen vorher / nachher

### Stufenwechsel lod0 → lod1 bei 60 m („Mittel“, `prop_scene --mode=lods`, Anker 20 m seitlich; Pixel mit Σ|ΔRGB| > 0,06 / Helligkeitssprung)

| Modell | 12 Uhr vorher (Kritik) | 12 Uhr nachher | 22 Uhr vorher (Kritik) | 22 Uhr nachher |
|---|---|---|---|---|
| Fachwerkzeile | 32,0 %, +4,7 % | **27,1 %, +3,2 %** | 23,8 %, +9,0 % | **18,7 %, +5,0 %** |
| Kontor | 24,7 %, −1,7 % | 25,7 %, +2,7 % | 18,1 %, +9,9 % | 19,5 %, **+8,1 %** |
| Barock | 18,5 %, −1,7 % | 19,1 %, −0,5 % | 13,9 %, +1,6 % | 14,2 %, +1,6 % |
| Gründerzeithaus | 18,0 %, −0,9 % | 18,6 %, +0,1 % | 14,1 %, +4,8 % | 14,3 %, +4,3 % |
| Speicher | 17,4 %, −0,9 % | 17,9 %, +1,1 % | 14,0 %, +4,4 % | 14,1 %, **+3,6 %** |
| Fachwerk mit Turm | 16,8 %, +2,7 % | 16,9 %, +0,6 % | 10,2 %, +5,7 % | 10,2 %, **+3,5 %** |
| Giebelzeile | 14,9 %, −2,1 % | 16,8 %, −0,8 % | 10,4 %, +1,3 % | 11,6 %, +0,8 % |
| Mietshaus | 14,2 %, −1,1 % | 13,7 %, +0,1 % | 10,5 %, +2,3 % | 10,1 %, +1,7 % |
| Einfamilienhaus | 11,1 %, +2,6 % | 17,2 %, +3,0 % (Gartenstufe 0,5) | 9,4 %, +3,9 % | 11,5 %, +4,3 % |
| Büroturm | 3,3 %, −0,1 % | 3,3 %, −0,1 % | 4,6 %, +2,1 % | 4,6 %, +2,1 % |
| Kran | 2,1 %, −0,1 % | 2,1 %, −0,1 % | 2,0 %, +7,2 % | 1,9 %, +4,4 % |

Der Rahmenring im gemalten Glas (`inner_frame`) nimmt den Nachtsprung dort, wo viele Fenster beleuchtet sind
(Fachwerkzeile, Turmhaus, Speicher, Kontor); der Anteil geänderter Pixel sinkt nur bei der Fachwerkzeile deutlich
(echte gegen gemalte Hölzer bleiben). Giebelzeile +1,9 Punkte: Ihre Straßenflanke mit 18 neuen Öffnungen liegt jetzt
mit im Bild. Einfamilienhaus siehe K10.

### Flimmern (`my_scene --mode=sparkcam`, Viertelpixel-Schritte seitlich, „Mittel“, 12 Uhr)

| Modell | 40 m | 60 m | 100 m (lod1) | 150 m (lod1) | Sprite 40 / 60 / 100 / 150 m |
|---|---|---|---|---|---|
| Fachwerkzeile | 1,2 % (vorher 1,1) | 1,4 % (1,4) | 0,6 % (0,6) | 1,1 % (1,1) | 0,1 / 0,1 / 0,2 / 0,4 % |
| Fachwerk mit Turm | 1,5 % (AS5a1: 1,0) | 1,4 % (1,0) | 0,6 % (0,6) | 1,1 % (0,8) | 0,2 / 0,3 / 0,4 / 0,5 % |
| Giebelzeile | 0,6 % (0,5) | 0,8 % (0,7) | 0,9 % (1,1) | 1,2 % (1,3) | 0,1 / 0,1 / 0,3 / 0,4 % |
| Gründerzeithaus | 0,6 % (0,6) | 0,7 % (0,5) | 0,3 % (0,3) | 0,3 % (0,4) | 0,1 / 0,1 / 0,2 / 0,4 % |

Nicht besser. Die 3 cm schmaleren Hölzer liegen zwar auf gemaltem Holz, aber Hölzer 3,5 cm vor der Wand zeigen bei
flachem Blick ihre Seitenflächen, und deren Kanten liegen über der Ausfachung. Das Turmhaus flimmert mehr, weil seine
Straßenflanke jetzt 19 Fenster mit Rahmen und Sprossen und der Erker Futter hat – Tiefe, die die Kritik gefordert hat.

### Geländer (`mipband.py` auf den gelieferten Atlanten; Kastenfilter in 8 Bit wie die Engine)

| Atlas | Deckung Mip 1 / 2 / 3 / 4 gegen Mip 0 | Helligkeit des Bandes gegen Mip 0 (Luma), Mip 1 / 2 / 3 / 4 |
|---|---|---|
| Mietshaus vorher | 1,11 / 1,20 / 1,40 / **0,30** | −2,3 / −4,2 / −8,2 / **+14,4** |
| Mietshaus nachher | 1,14 / 1,51 / 1,90 / 3,09 | +0,8 / +0,2 / +0,4 / −0,8 |
| Gründerzeithaus vorher | 1,12 / 1,19 / 1,32 / **0,59** | −5,2 / −8,4 / −13,6 / **+18,0** |
| Gründerzeithaus nachher | 1,15 / 1,54 / 2,01 / 2,84 | +1,1 / +0,8 / +2,3 / −0,0 |

Die Deckung steigt mit Absicht über 1: In den kleinen Mips schließt sich das Geländer zu einem Band, dessen Texel die
Mischfarbe aus Stäben und Hintergrund tragen – die Helligkeit, die das Auge bei Stäben unter einem Pixel sieht, bleibt
in jeder Stufe (|ΔL| ≤ 2,3 statt bis 18). Mip 0 ist unverändert (Deckung 0,32 bzw. 0,35 wie vorher), aus der Nähe
also dieselben Stäbe. „Hintergrund“ ist die Farbe aus dem Katalog (`cut_fill.color`: die verschattete Wand hinter dem
Balkon) – das Verfahren ist so gut wie diese Schätzung.

### Umriss gegen das Sprite (`k4_scene --mode=outline2`)

IoU lod0 / lod1 unverändert: Einfamilienhaus 0,993 / 0,993 (vorher 0,996: die dezimierte Hecke), Mietshaus 0,995 /
0,999, Gründerzeit 0,999, Büroturm 0,997, Fachwerkzeile 0,998 / 0,999, Turmhaus 0,999, Barock 0,999, Giebelzeile
0,998, Speicher 0,999, Kontor 0,987, Kran 0,922. Die neuen Öffnungen und Maueranker ändern den Umriss nicht.

### Texeldichte

Aus dem Bake (Modellmaß, Straßenwände): unverändert bis auf die Fachwerkzeile 34,2–42,7 px/m (vorher 35,0–43,8; die
neuen Laibungen der Flanke kosten Atlasfläche). Vertrag ≥ 26 px/m erfüllt außer Büroturm im Modellmaß (im Spiel bei
Maßstab 0,37–0,5: 32–57 px/m, gerechnet), wie bei AS5a1.


## Runden Bauen → Ansehen → Beheben

| Runde | Stand | gesehen | Folge |
|---|---|---|---|
| 0 | 63544b6 (AS5a1), Bilder `shots/vor` | Flanken blind (Fachwerk, Turmhaus ganz, Barock, Giebelzeile ganz), Erkerfenster gemalt, Konsole weiß; Prüfstraße bei 50 km/h: an jeder Altstadt-Flanke eine fensterlose Sockelwand | Befunde K2, K4 bestätigt |
| 1 | Proben (halber Atlas) Turmhaus, Giebelzeile, Barock, Fachwerkzeile, Mietshaus, Einfamilienhaus | Flanken mit Fenstern und Türen, Maueranker lesbar, Erker mit Fenstern; Konsole noch hellgrau; Geländer als Band (Mietshaus `mipband` ±1) | Konsole auf Sandstein `#a98a74` |
| 2 | Stufenbilder der Proben, Probe Gründerzeithaus | lod0/lod1 bei 60 m nachts deutlich ähnlicher (Rahmenring); Gründerzeit-Balkon bei 80–110 m als Band statt Pünktchen | Code eingefroren, echte Exporte |
| 3 | echte Exporte aller elf | Prüfer rot: 17 verkehrt gewickelte Dreiecke in der Gartenstufe des Hauses (Dezimierung 0,15) | 0,3: Prüfer grün, aber Stufenwechsel 20,8 % → 0,5 (17,2 %, 1 406 Dreiecke) |
| 4 | Endstand: Bilder aller Abstände, Nahansichten, Erker, Prüfstraße, Tönung, Umriss, Stufen, Flimmern, Rennen | siehe „Ehrliche Einordnung“ | – |

## Gates (Endstand, gemessen)

Endstand `7153381` auf `origin/wip/v080-as5ar1`. Alle Läufe mit `nice -n 19`, ein schwerer Lauf zur Zeit, absolutes
`XDG_DATA_HOME` im Arbeitsordner.

| Gate | Befehl | Ergebnis |
|---|---|---|
| Prüfer | `python3 tools/blender/validate_models.py --report` | `CHECK models OK` – Netze 18,86 von 40 MB, Texturen 57,53 von 240 MB im Grafikspeicher, Quellen 30,41 von 60 MB. Zwischendurch einmal rot (17 verkehrt gewickelte Dreiecke in der Gartenstufe des Hauses bei Dezimierung 0,15) – behoben, siehe Runde 3 |
| Sprite-Geometrie | `check_sprite_geometry.py --only props --jobs 1` (nach der letzten Änderung von `props_cities.py`) | `86 Sprite-Sets gebaut in 286 s: 86 identisch … 0 verändert, 0 fehlen` – `CHECK sprite_geometry OK` (der Hash umfasst auch die Materialien) |
| Schlüssel | `export_models.py --check-keys` | `CHECK cache_keys OK 98 Modelle` |
| Determinismus | Büroturm und Kran nach dem echten Export ein zweites Mal erzwungen exportiert und gebacken (`--force`, CE_THREADS=3) | beide **byte-gleich** (Hash der GLB und des Modellordners vorher = nachher) |
| AS4-Modelle | `git diff 63544b6 -- assets/models` | außerhalb `props/city_*` nur `manifest.json`; `buildings3d.py` unverändert. Die Modelle mit `props_cities.py` im Schlüssel (`bridge_pylon`, `bridge_pylon_bare`, `bridge_truss_arch`, `bridge_lamp`, `houseboat`) neu exportiert: byte-gleich |
| Rennen in Modern | `tools/ab_shot.sh`, 10 Läufe an vier Stadteinfahrten (siehe unten) | alle Bilder da, Exit 0, **0 Skriptfehler** in 20 Protokollen |
| Tests | `tools/run_tests.sh` (einmal, vollständig, 957 s für die Einheitstests) | alle Schritte grün bis auf einen Zeit-Test des Klangs: `test_engine3_checks :: test_engine_thread_in_a_running_game` (69 Aussetzer des Generators unter Last, 6 Hänger à 400 ms). Gefiltert wiederholt (`tools/run_tests.sh engine3_checks`): **2 Tests, 0 fehlgeschlagen** (0 Aussetzer). Derselbe Lastausreißer wie bei AS5a1; berührt keine Datei dieses Pakets. `test_music_checks` war diesmal grün |
| Arcade | `tools/golden.sh check` (einmal) | `GOLDEN arcade: 20 von 20 identisch`, `GOLDEN arcade-ui: 17 von 17 identisch` |
| Modern | `KEEP=… tools/golden.sh modern-check` | `GOLDEN modern: 4 von 6 identisch`; anders `modern_s4_mittel` (km 80,6) und `modern_s5_niedrig` (Ziel Hamburg) – dort stehen die neu exportierten Stadthäuser (Fensterflanke der Giebelzeile, Rahmenring); beide Bilder angesehen, gewollt; `modern-gles` OK (max. 2/255, PSNR 73,2 dB). Liste aus den behaltenen Bildern geschrieben (dieselbe Renderfunktion wie `modern-make`), Commit `7153381` |
| Archiv | `share.py` (deflate -9 je Datei der `.res`, `model.json` und importierten `.ctex`, wie `tools/pck_report.py`) | Netze **0,82 MB**, Texturen **5,36 MB** im Archiv (Anteil der Charge ≤ 3 / ≤ 7 MB; vorher 0,79 / 5,25 MB). Kein eigener Linux-Build (Abweichung) |


## Im Rennen: Arcade | Modern (`tools/ab_shot.sh`)

Dieselbe Simulation in beiden Modi (Seed 11, Limousine, Autopilot, Verkehr eingeschwungen, fliegender Start mit
50 km/h, Bilder 2 s und 4 s nach dem Start), an den Positionen der Kritik – damit stehen ihre Bilder als „vorher“ zur
Verfügung. 10 Läufe, jeder mit Arcade- und Modern-Bild: **alle Bilder da, Exit 0, 0 Fehlerzeilen** (`SCRIPT ERROR`,
`Parse Error`, `ERROR:`) in allen 20 Protokollen (gemessen). Ein Lauf brauchte 504–910 s.

| Ort | Hoch 12 Uhr | Hoch 22 Uhr | Mittel 19:30 | Was man sieht (angesehen) |
|---|---|---|---|---|
| Hamburg Innenstadt (Kiel–Hamburg km 88,2) | ja | ja | ja | Giebelzeilen beidseits: die Flanke des Treppengiebelhauses mit Fenstern statt Ziegelwand, nachts beleuchtet; Laden mit Auslage |
| Nürnberg Altstadt (Würzburg–Nürnberg km 102,7) | ja | ja | ja | links die Fachwerkzeile: Sandstein-Erdgeschoss jetzt mit Fenstern und Rundbogentür (vorher blind); rechts fehlt weiter das Turmhaus (K1, Korridorregel des Renderers) |
| Hannover (Hamburg–Hannover km 143,9) | ja | ja | ja | Gründerzeithaus mit Schaufenstern, Mietshäuser; wie vorher, Balkone als Band |
| München (Nürnberg–München km 161,7) | ja | – | – | links fehlen weiter Häuser (K1); rechts Gründerzeithaus ungetönt (K3) |

**Abweichung:** 10 statt 18 Läufe (jeder Ort Hoch 12 und 22 Uhr, Mittel 19:30, dazu München) – ein Lauf braucht auf der
geteilten Maschine 8–15 min; jede Voreinstellung und jede Uhrzeit kommt an jedem der drei Orte vor, nur nicht jede
Kombination. Kein Rennclip: An seiner Stelle stehen die Bildfolgen der Prüfstraße bei 50 km/h (vorher/nachher, dieselbe
Kamera).


## Ehrliche Einordnung

**Was der Spieler jetzt sieht** (Bilder dieses Ordners; Wirkung auf einen Menschen gefolgert):

- **In den Altstädten (Würzburg, Nürnberg, Fulda, München) und in Hamburgs und Bremens Innenstadt** zieht an der
  Straße keine fensterlose Wand mehr vorbei. Wo vorher der Sandstein-, Ziegel- oder Rustikasockel blind war, stehen
  Fenster mit Gewände, Rahmen und Sprossen und Türen mit Stufe; das Fachwerkhaus mit Turm hat an der Flanke dieselben
  Fensterreihen wie vorn, die Giebelzeile ihre Segmentbogenfenster über drei Geschosse, mit Granitsockel und
  Mauerankern. Nachts leuchten diese Fenster unregelmäßig und warm wie die Front – die Giebelzeilen-Flanke ist keine
  dunkle Platte mehr (`flanken_vorher_nachher_nacht.jpg`, Prüfstraße `pruefstrasse_*_vorher_nachher_*.jpg`).
- **Der Erker** des Turmhauses (95 Platzierungen) liest sich als Erker mit Fenstern: Futter, Sprossen, Sohlbank, nachts
  Licht hinter Sprossen statt gelber Felder; die Konsole ist Stein, kein weißer Kegel.
- **Balkone** von Mietshaus und Gründerzeithaus: Das Geländer verschwindet ab 75 m nicht mehr und wird bis 40 m nicht
  mehr dunkler, es wird in der Ferne zu einem Band mit gleicher Helligkeit (`gelaender_*.jpg`).
- **Stufenwechsel**: nachts kleinerer Helligkeitssprung (Fachwerkzeile +9 → +5 %), sonst wie vorher.

**Was noch nicht gut ist** (gemessen, wo eine Zahl steht):

1. **Flimmern der Fachwerkhölzer** in Bewegung: 1,2–1,5 % der Pixel je Viertelpixel-Schritt bei 40–60 m gegen 0,1–0,3 %
   beim Sprite – unverändert. Mein Versuch (Hölzer schmaler als das gemalte Holz) hat nichts gebracht. Ohne Hölzer als
   Geometrie wäre es so ruhig wie lod1 (0,6 %), aber die Tiefe aus der Nähe wäre weg; die richtige Lösung ist eine
   kürzere lod0-Entfernung je Modell (~35 m) oder Überblenden im Renderer.
2. **Stufenwechsel bei 60 m** ändert weiter 13–27 % der Pixel (Fachwerkzeile, Kontor am meisten). Ohne Überblenden (R7)
   bleibt er für einen aufmerksamen Spieler an freistehenden Häusern sichtbar (gefolgert).
3. **Einfamilienhaus**: Die leichtere Gartenstufe (1 406 statt 2 526 Dreiecke) ändert beim Wechsel mehr Pixel als vorher
   (17,2 statt 11,1 %), weil die Hecken anders facettiert sind – in den Bildern bei 60 m nicht zu unterscheiden
   (angesehen), aber gemessen schlechter.
4. **Neue Flanken sind im Sprite nicht da**: Sie sind „im Stil des Generators“ ergänzt (dieselben Rasterfunktionen,
   Fenstertypen und Farben wie die Front), aber kein Bestandteil des Sprites – siehe Vertragsfrage.
5. Unverändert aus AS5a1: Büroturm-Foyer nachts flach, Kontor oben 24 px/m bei Maßstab 1,2, Tönung erst mit R7, die
   Konsole des Erkers bleibt ein glatter Kegel (nur in Stein).

**Was fehlt:** Messungen auf echter Grafikkarte (MSAA dort mildert das Flimmern – gefolgert) und auf dem Steam Deck; ein
Rennclip (Zeit: Prüfstraßen-Bilder bei 50 km/h stehen dafür); die zweite Hälfte der Stilfamilien (AS5a2/AS5b).


## Für andere Pakete

- **Leitung (Vertrag):** Die Flankenöffnungen ergänzen, was das Sprite nicht zeigt („die Generatoren SIND das
  Aussehen“ gegen „Tiefe, wo die Kamera von der Straße hinsieht“). Ich habe sie streng aus den Mitteln des Generators
  gebaut (dieselben `grid`-Raster, Fenstermaße, Rahmen- und Glasfarben, Lichtregeln wie die Front) und hinter `close3d`
  gelegt. Bitte bestätigen; AS5a2/AS5b (Grachtenhäuser, Reihenhäuser, Haussmann) brauchen dieselbe Regel.
- **R7:** Überblenden lod0 ↔ lod1 auch für Gebäude (A-16 nennt nur Bäume); eine lod0-Entfernung je Modell aus
  `model.json` (`max_dist_m`, für Fachwerkhäuser ~35 m) würde das Flimmern der Hölzer nehmen, ohne die Tiefe aus der
  Nähe zu verlieren. Tönung als Instanzfarbe auf die gebackene Albedo (`toenungen.jpg`).
- **R7/Renderer:** Mit `cut_fill` brauchen die Geländer kein Alpha-to-Coverage mehr; der Alpha-Test bei 0,5 muss
  bleiben (die Lücken haben Alpha 0,4).
- **Leitung/R2:** Kurvenkorridor (K1) – in München fehlen weiter Häuser, wenn die Korridorregel nicht geändert wird.
- **R4:** Sonnenseite heller Putzfassaden gegen Arcade abgleichen (K8); ich habe die Albedo bewusst nicht abgedunkelt.
- **AS5a2/AS5b:** Bauer `city` weiterverwenden: `close3d`-Flanken von Anfang an, `oriel` für Turmerker, `cut_fill` für
  jedes Geländer (Haussmann!), `inner_frame` gilt automatisch.
- **Nacharbeit offen:** Flimmern der Hölzer (siehe oben), Büroturm-Foyer, Kontor-Texeldichte, Konsole als Profil statt
  Kegel.


## Lieferung (dieser Ordner)

Alle Bilder auf dieser VM gerendert (llvmpipe), Renn-Look; „vorher“ = Stand 63544b6 (AS5a1), „nachher“ = Endstand.

| Datei | Inhalt |
|---|---|
| `flanken_vorher_nachher_tag.jpg`, `_nacht.jpg` | Straßenflanke von Fachwerkzeile, Turmhaus, Barock und Giebelzeile, vorher / nachher, 12 und 22 Uhr (K2, K4) |
| `pruefstrasse_altstadt_50kmh_vorher_nachher_{tag,nacht}.jpg` | Prüfstraße der Kritik (Altstadt beidseits, 50 km/h, Hoch), dieselbe Kamera: Bilder 20, 40, 60 vorher / nachher |
| `pruefstrasse_hanse_50kmh_vorher_nachher_{tag,nacht}.jpg` | dasselbe mit Giebelzeilen und Speicher |
| `erker_vorher_nachher.jpg` | Erker des Turmhauses: Bild 31 der Kritik, nachher 12 und 22 Uhr (K4) |
| `gelaender_vorher_nachher.jpg` | Erkerbalkon des Gründerzeithauses bei 80 und 110 m (Hoch, 3× vergrößert): vorher Pünktchen, nachher Band (K7) |
| `gelaender_abstaende_mittag.jpg` | Mietshaus und Gründerzeithaus bei 15/40/80/110 m, darunter das Arcade-Sprite |
| `stufenwechsel_mittel_{tag,nacht}.jpg` | lod0/lod1 bei 60 m, lod1 und Sprite bei 200 m, alle elf, „Mittel“ (Einfamilienhaus darin noch mit Gartenstufe 0,3) |
| `stufenwechsel_haus_geliefert.jpg` | Einfamilienhaus mit der gelieferten Gartenstufe 0,5 |
| `flimmern_messbild.jpg` | Messbild der Flimmermessung |
| `umrisse_sprite_gegen_modell.jpg` | Umriss in der Sprite-Kamera, alle elf |
| `toenungen.jpg` | getönte Platzierungen: Modell, Albedo × Tönung, Sprite × Tönung, Sprite (für R7) |
| `abstaende_{german,altstadt,hanse}_{mittag,daemmerung,nacht}.jpg` | Spielkamera bei 10/30/100/250 m, darunter das Arcade-Sprite (Hoch). Die Prüfszene zeigt am Sprite kein Nachtlicht – Licht nur im Rennen vergleichen (Hinweis der Kritik) |
| `nahansichten_{german,altstadt,hanse}_{tag,nacht}.jpg` | Straße, schräg, vorn, hinten (lod0, Hoch) |
| `rennen_*.jpg` | Arcade \| Modern im Rennen (`tools/ab_shot.sh`); wo die Kritik dieselbe Stelle und Zeit hatte, oben „vorher“ (ihr Bild), unten „nachher“ |
| `golden_modern_s{4,5}_vorher_nachher.jpg` | die zwei geänderten Modern-Goldens, links AS5a1, rechts Endstand (angesehen vor dem Neuschreiben der Liste) |
| `bericht.md` | dieser Bericht |

