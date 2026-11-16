# AS2a – Spielerautos und Verkehrsautos, der Rest: Bericht

- Paket: AS2a (v0.8.0, Vorstart M2) · Zweig `worktree-wf_72970c4d-66e-1` · Sicherheitskopie `origin wip/v080-as2a`
- Arbeitsbaum: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-1`
- Basis: `c478902` (AS1R, ff) + R3 `4d02ada` per `--no-ff` (`fa6560c`). Alle Zahlen **gemessen** auf dieser VM
  (Software-OpenGL llvmpipe unter Xvfb, 4 geteilte Kerne), wo nichts anderes steht; alles über Steam Deck, echte
  Grafikkarten und die Wirkung auf einen Menschen ist **abgeleitet**.
- Doku: `docs/modelle.md` Abschnitt 14 (neu), Abschnitte 1, 2, 8, 11, 12, 13 nachgezogen.
- Commits: `d527535`, `eda9449`, `0d3bdc3`, `135b265`, `19aa138` (Kopf, gepusht nach `wip/v080-as2a`).

## 1. Was geliefert ist

**Neue Modelle (6):**

- `player/kombi`, `player/sportwagen`, `player/gran_turismo`: Rennstufe `lod0` aus den Detailstufen des
  Generators, Showroom-Stufe `show`, Schattenwerfer, Innenraum, durchsichtiges getöntes Glas – gebaut wie AS1
  Limousine und Kompakt.
- `traffic/suv` (4 Farbsets), `traffic/van` (4), `traffic/sports` (5): eingeschnittene Flächen (Decals als
  Geometrie), `lod0`–`lod2`, Schattenwerfer, jedes Farbset als `paint` des Sets.

**Für alle fünf Spielerautos** (also auch Limousine und Kompakt von AS1 neu gebaut):

- Innenraum als Generator-Modul `cesprites/carinterior.py` (vorher `ce3d/interior3d.py`): Sitze mit
  Kopfstützen, Armaturenbrett, Lenkrad links, Türverkleidungen, Hutablage; Rückbank nur, wo Platz ist (Sportwagen
  und GT: 2+2, Bank schmaler über den Radhäusern).
- Echtes durchsichtiges, getöntes Glas (Deckkraft 0,48; der Innenraum ist aus der Spielkamera zu sehen).
- 3D-Korrekturen des Vertrags: **Rückleuchten um die Ecke** (seitliche Mulde mit Füllung, Lichtleiter,
  Streuscheibe; nicht bei den runden Leuchten des Sportwagens), **Kühlergrill / Lufteinlass als Mulde mit Lamellen**
  (Kombi, Sportwagen, GT neu; Kompakt, Limousine schon), **Spiegelarme aus der Karosserie**, sichtbare Projektoren,
  dritte Bremsleuchte mit Richtung.
- Felgenstil je Auto wie im Sprite (Kompakt 6 Doppelspeichen schwarz, Kombi 10 gerade Speichen silber, Limousine
  5 Doppelspeichen, Sportwagen 5 Y-Speichen schwarz, GT 10 gebogene Turbinenspeichen silber).

**Sets:** alle 26 Pkw-Verkehrssets und alle 5 Spielerautos (plus 5 Showroom-Sets) lösen zu einem Modell auf
(gemessen mit dem Manifest: 26/26, 5/5, 5/5). `showroom` bleibt bei allen fünf `false` (Abschnitt 5).

## 2. Abnahme

| Prüfung | Ergebnis | Beleg (gemessen) |
|---|---|---|
| Prüfer `validate_models.py` | grün | `CHECK models OK` – 16 Modelle, 180 Sets (44 mit Modell, 136 Platzhalter); Netze 10,28 MB von 40 MB |
| Alle 26 Pkw-Sets + 5 Spielerautos lösen auf | ja | Manifest: 26/26 Verkehr, 5/5 Rennen, 5/5 Showroom |
| Budgets §4.6.9 | eingehalten | Tabelle Abschnitt 3 (der Prüfer prüft jede Stufe) |
| `showroom`-Flags per A/B | entschieden: alle `false` | Abschnitt 5, Bild 07 |
| `check_sprite_geometry` (kein „ANDERS“) | grün | 187/187 identisch (1 × nur andere Flächenreihenfolge, Fernsehturm), `CHECK sprite_geometry OK` |
| Export-Determinismus | grün | erzwungener Export + Bake aller `player/*`, `traffic/*`: `git status` leer; zweiter Bake byte-gleich (80 Dateien); `--check-keys`: `CHECK cache_keys OK` (16 Modelle) |
| `tools/run_tests.sh` (einmal, am Ende) | **rot: 2 Checks** (beide in R3s `check_vehicles.gd`, Ursache: die neuen Modelle, Abschnitt 8) | 594 Unit-Tests, 0 fehlgeschlagen; 79 Checks, 77 OK, `kasten` und `leistung` FEHLER; 241 Skripte ohne Fehler; 596 s |
| `tools/golden.sh check` (einmal, am Ende) | grün | `GOLDEN arcade: 20 von 20 identisch` (189 s, `JOBS=1`) |
| ≥ 3 Runden bauen/rendern/ansehen/beheben | 4 Runden | Abschnitt 4 |

## 3. Zahlen je Modell (gemessen, Stand des letzten Commits)

Dreiecke je Stufe (Budget §4.6.9: Spieler `lod0` 55 000, `show` 120 000, Schatten 3 000, Innenraum 6 000;
Verkehr 18 000 / 6 000 / 1 200), Zeichenaufrufe, Netzbytes, Exportzeit (`--jobs 1`, `nice 19`, VM geteilt):

| Modell | Stufen | Innenraum | Aufrufe | Netze | Export |
|---|---|---|---|---|---|
| `player/kombi` | lod0 **54 306** · show **117 206** · Schatten 2 320 | 3 860 | 6 / 6 | 1 964 901 B | 20,6 s |
| `player/sportwagen` | lod0 46 940 · show 95 375 · Schatten 2 320 | 3 514 | 6 / 6 | 1 690 967 B | 13,9 s |
| `player/gran_turismo` | lod0 48 095 · show 102 327 · Schatten 2 320 | 3 412 | 6 / 6 | 1 772 777 B | 15,0 s |
| `player/limousine` (neu gebaut) | lod0 47 904 · show 98 786 · Schatten 2 320 | 3 560 | 6 / 6 | 1 637 806 B | 16,5 s |
| `player/kompakt` (neu gebaut) | lod0 49 155 · show 106 649 · Schatten 2 320 | 3 658 | 6 / 6 | 1 770 933 B | 16,7 s |
| `traffic/suv` (4 Sets) | 17 824 · 5 915 · 1 169 · Schatten 1 004 | – | 6 / 1 / 1 | 280 642 B | 2,5 s |
| `traffic/van` (4 Sets) | 17 655 · 5 845 · 1 189 · Schatten 1 064 | – | 6 / 1 / 1 | 270 960 B | 2,4 s |
| `traffic/sports` (5 Sets) | 17 751 · 5 741 · 1 194 · Schatten 972 | – | 6 / 1 / 1 | 287 195 B | 2,5 s |

Knapp am Budget: Kombi `lod0` (98,7 %) und `show` (97,7 %), Sports `lod2` (99,5 %). Alle Netze zusammen 10,28 MB
von 40 MB.

Lampenflächen von hinten bzw. vorn (cm², `inspect_models.gd`, Regel Spieler 200 / 100 / 60 / 80 / 15, Verkehr
200 / 100 / 60 / 80 / 40):

| Modell (Stufen) | Rücklicht | Bremslicht | Blinker hinten je Seite | Scheinwerfer | Blinker vorn |
|---|---|---|---|---|---|
| Kombi (lod0 / show) | 782 / 820 | 751 / 785 | 78–79 | 92 / 93 | 28–29 |
| Sportwagen | 804 / 803 | 767 / 764 | 66 | 85 / 84 | 30–31 |
| Gran Turismo | 390 / 385 | 327 / 342 | 72–73 | 102 / 101 | 31–32 |
| Limousine | 887 / 882 | 841 / 839 | 80–84 | 90 / 89 | 19–20 |
| Kompakt | 929 / 922 | 901 / 898 | 100–102 | 101 / 103 | 27–28 |
| SUV (lod0 / 1 / 2) | 775 / 895 / 740 | 731 / 851 / 880 | 120 | 264 / 329 / 414 | 108 / 98 / 90 |
| Transporter | 489 / 624 / 763 | 596 / 736 / 875 | 82–86 | 476 / 505 / 583 | 109 / 109 / 100 |
| Sportwagen (Verkehr) | 830 / 940 / 933 | 830 / 940 / 933 | 71–74 | 142 / 212 / 241 | 85 |

Lichtanker: keiner liegt unter seiner Lampe (höchstens 0,9 mm, erlaubt 3); alle mit Richtung.

Radfreiheit (Netz-Dump, numpy; Reifenvolumen gegen Karosserie): Hinterräder aller Spielerautos 0 mm; Vorderräder
Kompakt, Kombi, Limousine 0 mm, **Sportwagen 84 mm, GT 61 mm** (Lack über dem Reifenscheitel, Abschnitt 6);
Verkehr SUV, Van 0 mm, Sports 32 mm erst bei 15° Lenkeinschlag (Verkehr lenkt nur atan(Radstand × Krümmung),
abgeleitet: unter 5°).

Stufenwechsel (Spielkamera, Tag, Anteil der Autopixel, die sich um mehr als 24 Stufen ändern; Bilder 12/13):
40 m `lod0` → `lod1`: SUV 5,6 %, Transporter 4,7 %, Sportwagen 9,3 % (AS1R-Typen 6,6–9,8 %); 120 m `lod1` →
`lod2`: 32,3 / 33,9 / 37,2 % (AS1R-Typen 22–34 %; Sportwagen vor Runde 4: 42,6 %).

Sprite-Geometrie: `check_sprite_geometry.py --jobs 1`: 187 von 187 Sets identisch (eines, der Berliner
Fernsehturm, mit anderer Flächenreihenfolge – bekannt, zählt als identisch), 697 s, `CHECK sprite_geometry OK`.

## 4. Runden (bauen → rendern → ansehen → beheben)

Vier Runden, jede mit Kontaktbögen/Nahbildern und – wo die Ursache nicht zu sehen war – numerischer Analyse der
gebackenen Netze (Dump der `.res`, numpy).

| Runde | Befund (gemessen bzw. gesehen) | Ursache | Behebung |
|---|---|---|---|
| 1 Verkehr | Budgets überschritten (SUV lod0 18 377 / lod1 6 422 / lod2 1 311, Van lod0 19 910 / lod1 6 355, Sports lod0 18 477 / lod2 1 233) | mehr Decals (Verkleidung, Dachreling, Flügel, 4 Endrohre) | Detail-Overrides je Modell in `catalog3d`, Flügel-Fase 1 Segment, verdeckte Flügelflächen gelöscht |
| 1 Verkehr | Sports `lod0`: Rückleuchten schwarz; `lod1` zeigte mehr Rücklicht (937 cm²) als `lod0` (408) | Decal-Gruppen in der Reihenfolge ihres ersten Auftretens: der Lampenring lag über dem Rot | `CAR_3D["sports"]["order"]` |
| 1 Verkehr | Lichtanker SUV 4,5 mm, Van 5,6 mm unter der Lampe (Grenze 3) | Stoßfänger-Rückstrahler zogen den Anker; Van-Blinker um die Ecke | Rückstrahler `-tail:0.3` (kein Anker), Van-Blinker auf der Heckfläche |
| 1 Verkehr | 15 Dreiecke gegen ihre Normalen (Sports) | Loft-Ringe verdreht an Radlaufkanten | `_drop_flipped_slivers` |
| 2 Spieler | Kombi `lod0` 57 033 > 55 000 | 4,8 m langer Loft | Stationsabstand 3,7 → 54 086 |
| 2 Spieler | Blinker GT 50 cm² (< 60), Scheinwerfer Sportwagen/GT < 80 cm² | schmale Leuchten der Entwürfe | Blinkerstreifen, zweiter Projektor (nur 3D) |
| 2 Spieler | Kombi: dritte Bremsleuchte ohne Richtung; 14 / 9 verkehrt gewickelte Dreiecke (Kombi / Sportwagen) | geschlossener Kasten; gefaltete Pfadflächen | `brake3` (nach hinten leuchtende Fläche), `_drop_flipped` |
| 2 Spieler | Rückleuchte um die Ecke saß an der C-Säule; Projektoren unsichtbar | Sprite-Umrisse ragen über die Ecke; Projektor unter dem Chrom | äußerstes Leuchtenende per Strahl von hinten; Projektor-Versatz |
| 3 Blick | Showroom-A/B: Glas heller als im Sprite | Deckkraft 0,35 | 0,48 (Innenraum bleibt sichtbar) |
| 3 Blick | Rückbank Sportwagen/GT 89 / 60 mm in den Hinterreifen (verdeckt) | 2+2 über der Hinterachse | Bank schmaler über den Radhäusern → 0 mm |
| 4 Lieferbilder | Sportwagen-Lufteinlass: rote Bänder zwischen den Lamellen; Kompakt, Limousine, Kombi: Lack im selben Tiefenband wie der Muldenboden | Front der Karosserie 1–4 cm hinter der Stoßfängerhaut, Mulde nur im Stoßfänger | Mulde durch alle Körper unter der Kontur (Fenster der Einlässe: nur noch Boden und Lamellen) |
| 4 Lieferbilder | Verkehrs-Sportwagen `lod2`: Heckscheibe diagonal halb Lack, Stufensprung 120 m 42,6 % | 17° flache Scheibe auf der Schwelle 0,3 der Normalenregel | `far_pane_ny` 0,25 nur für ihn (eine Bereichsregel verschlechterte die Limousine – verworfen) |

## 5. Showroom-Entscheid (A/B mit derselben Kamera, Lieferbild 07)

Showroom-Kamera der Sprites, Echtzeit-Stufe `show` links, Cycles-Sprite rechts, Tonemapper AgX wie im Showroom.
**Alle fünf `showroom`-Flags bleiben `false`.** Form, Fugen, Lampen, Felgen, Kennzeichen stimmen, und die
Echtzeit-Stufe hat sogar mehr Modell (Innenraum hinter echtem Glas, Lampen mit Tiefe). Was ihr fehlt, ist Licht:

- keine Spiegelung der Umgebung im Lack, kein Klarlack-Glanzlicht über die Rundungen – der Lack wirkt flach;
- keine Umgebungsverdeckung in Fugen, Radhäusern und unter dem Auto, kein Kontaktschatten – das Auto „schwebt“;
- das Glas ist heller und spiegelt kaum (im Sprite fast schwarz mit Himmelsreflex);
- unter AgX wird das Gelb des Kompakt und das Rot blass.

Das liegt nicht im Netz, sondern im Showroom-Licht und in der Umgebungsspiegelung (R3/UI1). Umschalten ist eine
Zeile je Set im Katalog, sobald ein A/B gleichwertig ist (abgeleitet: frühestens mit einer Umgebungs-Cubemap im
Showroom).

## 6. Schwächste Stellen (für die Kunstkritik)

1. **Lack und Licht** (alle Autos, Renderer): unbeleuchtete Lampen wirken bei Tag eingeschaltet (`lamp_off` 0,5),
   Lack ohne Umgebungsspiegelung, kein Kontaktschatten. Am Modell nicht lösbar.
2. **Vorderräder Sportwagen und GT**: Der Reifen steckt oben 84 bzw. 61 mm im Lack (gemessen, Lenkwinkel 0°): Die
   Schulterkante der Entwürfe läuft unter dem Scheitel des Radlaufs, die Haube ist zu tief für eine Kante darüber.
   Von außen verdeckt; im Radhaus von schräg unten könnte man es sehen. Eine Lösung braucht einen anderen
   Querschnitt der Front (Sprite-Geometrie fest → nur ein 3D-Hook).
3. **Blinker vorn/hinten der Spielerautos leuchten nie** (das Spiel setzt beim Spieler keine Blinker), der Prüfer
   verlangt sie trotzdem; bei Tag sind die bernsteinfarbenen Felder sichtbar (halbe Leuchtfarbe).
4. **Kennzeichen beim Wechsel 40 m**: In `lod0` dunkle Zeichen auf hellem Grund, in `lod1` die graue Mittelfarbe –
   bei 40 m sichtbar als kleiner Helligkeitssprung (Teil der 4,7–9,3 %).
5. **Verkehr bei 120 m**: `lod2` hat dreieckige Radausschnitte und eine Kabine aus wenigen Flächen; die Wechsel
   ändern 32 / 34 / 37 % der Autopixel (SUV, Van, Sports; AS1R-Typen 22–34 %) – im Rennen sind das 12 × 9 Pixel.
   Der Transporter wechselt vor allem in der Heckscheibe (in `lod1` heller gespiegelt).
6. **Innenraum**: grob (Kästen, ein Lenkrad-Torus), dunkel; von hinten durch das Glas als Silhouette lesbar, aus
   der Nähe einfach. Keine Instrumente, keine Pedale.
7. **Transporter**: Seiten ohne Fenster hinten (wie das Sprite), sehr glatte große Flächen.

## 7. Was die Modelle vom Renderer brauchen (R3, nicht im Modell lösbar)

- `lamp_off` für Fahrzeuglampen etwa 0,25–0,3 statt 0,5 (rot und bernstein wirken bei Tag eingeschaltet).
- Lackbelichtung: Gelb und Weiß übersteuern im Kontaktbogen (Verdacht: Exposure der Fahrzeug-Ebene).
- Kontaktschatten/AO unter dem Auto; Idee ohne Renderer-Arbeit: die Vertexfarbe des Lacks unten abdunkeln
  (COLOR.rgb ist bei Lack bisher Weiß) – nicht umgesetzt, weil das den Lack-Slot des Sets verändert.
- Showroom: Umgebungs-Cubemap und weiches Licht, sonst bleibt `showroom` `false`.

## 8. Abweichungen vom Vertrag, Vertragsfragen

- Dateien außerhalb der Liste von AS2a angefasst (alle Fahrzeug-3D-Bau, sonst niemandem zugeordnet):
  `ce3d/{traffic3d, vehicles3d, decalgeo, extras3d, __init__}.py`; `ce3d/roles.py` (steht in der Liste).
- `cesprites/carinterior.py` ist das verschobene `ce3d/interior3d.py` (der Vertrag nennt die neue Datei).
- Nur-3D-Teile (das Sprite bleibt gleich): Blinkerstreifen und zweiter Projektor (Sportwagen, GT), Rückfahrlicht
  des Kombi, Spiegelglas, Lampen um die Ecke, Mulden. Grund: Lampenregel des Prüfers (Regel 9).
- Showroom-Entscheid mit dem Rig des Kontaktbogens (Showroom-Kamera, AgX) statt mit dem Showroom von UI1, den es
  noch nicht gibt.
- AS1-Modelle mitgebaut: Limousine und Kompakt (Spieler) tragen jetzt die Korrekturen für alle fünf; Verkehrs-
  Limousine und -Kombi verloren in `lod0` 3 bzw. 5 verdrehte Splitter-Dreiecke (Limousine 1 in `lod1`,
  `_drop_flipped_slivers`); ihre `lod2` und das ganze Schrägheck sind byte-gleich zur Basis.

**Vertragsfrage – `tests/race3d/check_vehicles.gd` (R3) scheitert an zwei Stellen, beide wegen der neuen Modelle**
(gemessen, deterministisch, Seed 11; die Datei gehört nicht AS2a, sie ist **nicht** geändert):

1. `kasten`: Der Test nimmt `traffic/sports_red` als „Set ohne Modell“ – AS2a muss genau dieses Set mit einem
   Modell versorgen (alle 26 Pkw-Sets). Vorschlag: ein Set, das noch keins hat, z. B. `traffic/bus_red` (bis AS2b)
   neben `police/at`.
2. `leistung`: „keine Knoten gebaut, solange dieselben Autos fahren (34 → 35)“. Diagnose (Kopie des Tests mit
   Ausgabe je Bild): Das Verkehrsauto id 1 der Etappe, `traffic/sports_yellow`, fährt in Bild 17 über 120 m
   (`lod1` → `lod2`, 126,2 m); `layers/vehicles.gd` baut eine Stufe beim ersten Gebrauch (`_set_level`). Vor AS2a
   war dieses Set ein Kasten ohne Stufen. Vorschlag (R3/R4): beim Erscheinen alle Stufen eines Modells bauen, oder
   den Test nur Bauten neuer Autos zählen lassen. Die Zeit je Auto bleibt im Rahmen (Median 33–34 µs ≤ 40 µs).

## 9. Lieferbilder (`deliver/AS2a`)

| Datei | Inhalt |
|---|---|
| `01_spieler_spielkamera_tag_8_9_30m.jpg` | alle 5 Spielerautos aus der Spielkamera 8 / 9 / 30 m, je daneben das Arcade-Sprite |
| `02_spieler_spielkamera_nacht.jpg` | dasselbe nachts: Rücklicht, Bremse + Blinker |
| `03_kontaktbogen_tag_spieler.jpg` | Kontaktbogen Tag: `lod0`, `show`, Schattenwerfer |
| `04_kontaktbogen_nacht_spieler.jpg` | Kontaktbogen Nacht: jeder Lampenzustand |
| `05_kontaktbogen_tag_verkehr.jpg` | SUV, Van, Sports: `lod0`–`lod2`, Schattenwerfer, alle Farbsets |
| `06_kontaktbogen_nacht_verkehr.jpg` | dieselben nachts, jeder Lampenzustand |
| `07_showroom_ab.jpg` | Showroom-A/B je Spielerauto |
| `08_nah_<auto>.jpg` (5) | Nahbilder: Heck, Rückleuchte Tag/Nacht, Räder, Radhaus, Innenraum, Scheinwerfer |
| `09_verkehr_nah.jpg` | SUV, Van, Sports nah |
| `10_verkehr_spielkamera.jpg` | SUV, Van, Sports aus der Spielkamera 10 / 30 / 80 m, Tag und Nacht |
| `11_lampenkanaele.jpg` | Prüfstreifen der Lampenkanäle |
| `12_stufen_40m.jpg`, `13_stufen_120m.jpg` | Stufenwechsel bei 40 / 120 m mit Differenzbild |

Alle Bilder: Software-OpenGL unter Xvfb, Spiel-Shader mit dem Look der Fahrzeug-Ebene (R3), aber das Licht des
Kontaktbogens. Farben wirken dort heller und satter als im Sprite; die Belichtung im Rennen legt der Renderer fest.

## 10. Ehrliches Urteil

**Gut:** Aus der Spielkamera (9 m, das ist das Rennen) stimmen Umriss, Proportionen, Lampen, Kennzeichen und
Felgen der fünf Spielerautos mit ihren Arcade-Sprites überein (Bild 01); die Rückleuchten laufen um die Ecke,
durch die Scheiben sieht man Sitze und Kopfstützen, nachts leuchten Rück-, Brems- und Kennzeichenlicht klar
getrennt (Bild 02). Grills und Einlässe haben echte Tiefe. Die drei neuen Verkehrstypen lesen sich bei 10–30 m
eindeutig als SUV, Transporter und Sportwagen, mit Lampen in jeder Stufe.

**Noch nicht:** Der Lack ist flacher und heller als im Sprite (Renderer); unbeleuchtete Lampen wirken bei Tag halb
an; der Innenraum ist aus der Nähe grob; Sportwagen und GT haben über dem Vorderrad Lack im Reifen (verdeckt).
Bei 120 m wechseln die Verkehrsautos sichtbar die Stufe (32–37 % der Pixel eines 12 × 9-Pixel-Autos).

**Fehlt:** Showroom-Gleichwertigkeit (Umgebungsspiegelung, Kontaktschatten) – deshalb alle `showroom` `false`.

## 11. Hinweise für die Nacharbeit

- Kunstkritik zuerst an: Bild 07 (Lack/Glas gegen Sprite), Bild 08 Sportwagen/GT (Vorderrad, Front), Bild 13
  (120 m), Bild 04 (Lampen bei Tag „an“).
- `showroom` umschalten: je Set eine Zeile in `ce3d/catalog3d.py` (`"showroom/<auto>": {..., "showroom": True}`),
  dann Export/Bake/Manifest – erst nach einem A/B mit dem Showroom-Licht.
- Lampenzustände des Spielers: Wenn das Spiel je Spieler-Blinker bekommt, sind die Felder da (≥ 15 / ≥ 60 cm²).
- Werkzeuge: Kontaktbogen `--look=race` (Standard), `--day`, `--arcade` (Sprite daneben), `--tonemap=agx`,
  Kommas in `--only`; `CE_STATS=1` zeigt Mulden und Rückleuchten-Ecken.
- Budgets: Kombi `lod0` hat noch 694 Dreiecke Luft, Sports `lod2` 6 – jede weitere Zierleiste braucht dort
  längere Stationsabstände (`catalog3d` `detail`).
