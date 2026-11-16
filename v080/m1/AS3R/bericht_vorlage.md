# AS3R – Nacharbeit Vegetation und Natur nach der Kunstkritik (Bericht)

- Zweig `worktree-wf_aad8d49e-fb4-4`, Arbeitsbaum `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-4`,
  Sicherung `origin/wip/v080-as3r` (nach jedem Commit gepusht). Basis **be866d2** (AS3, ff-merge), Endstand **⟨HEAD⟩**.
- Commits: aee59b8 (Runde 1), 4fb8187 (Runden 2–5: lod1, Fernbild, Abgleich), 638debc (Holz, voller lod1-Rand, palm_b,
  Doku)⟨HEADNOTE⟩.
- **gemessen** = ein Befehl hat die Zahl ausgegeben (auf dieser VM: Mesa llvmpipe unter Xvfb, Renn-Licht von
  `tools/models/prop_scene.sh --look=race`, Voreinstellung „Mittel“); **angesehen** = Urteil nach Bildern;
  **gefolgert** = nicht messbar (echte GPU, Steam Deck) oder aus dem Code abgeleitet.
- „vorher“ = die Messungen der Kunstkritik KRITIK-3 auf be866d2 mit demselben Werkzeug (`kritik_scene.gd` der Kritik,
  hier als unversionierte Kopie benutzt und am Ende gelöscht; `prop_scene.sh --mode=lods`).

## 1. Kurzfassung

- **Die drei „gröber als das Sprite“-Mängel sind behoben** (angesehen, gemessen):
  - Birkenstamm: weiße Rinde mit dünnen Querbändern statt Schachbrett aus Dreiecken (Bild 01).
  - Klippe: geschlossener Felskörper – von hinten und von der Seite Fels statt Fetzen und Horn, aus allen
    8 Drehungen (Bild 02); Kennzeichen `face_road` für den Props-Bauer.
  - Palme: breitere, hängende Wedel und dunkler Stamm mit feinen Ringen; Sprite zu 83 % gedeckt (vorher 69 %),
    `palm_b` 27 % außerhalb (vorher 57 %) (Bild 06).
- **Fernbild** (M5): Relief im Licht des Sprite-Rigs auf den eigenen Normalen, normiert; Fichte zusätzlich mit
  Cycles-Schatten (Etagen). Mittags Kontrast gegen lod1 jetzt −22 … +14 % (vorher −30 … −80 %; Palme weiter −60 %),
  Sättigung −7 … +9 % (vorher −5 … −19 %), Helligkeit −9 … +6 %; im fernen Nebel wie das Sprite. Abends und nachts
  trägt das Fernbild sein Mittagsrelief: Kontrast dann +10 … +121 % über lod1, nachts Fichte, Palme und Zypresse
  14–32 % heller (wenige Grauwerte).
- **Stufenwechsel** (M6): lod1 liegt auf dem Rand von lod0 (jede zweite Randecke, bei Restbudget der ganze Rand).
  Helligkeit lod0 → lod1 mittags innerhalb ±5 % bei allen Modellen; abends und nachts springt `olive_b` um +6,5 bzw.
  +8,3 % (Rückschritt, Abschnitt 10). Der Anteil geänderter Pixel bleibt bei 63–73 % (Laubbäume; Kiefer 34–37 %,
  vorher 43–44 %): ein harter Wechsel bleibt sichtbar – die Abhilfe ist die Überblendung im Props-Bauer (R2/R7).
- **Büsche** (M4): höchstens 15 Kuppeln mit 12-Eck-Rand statt 5-Eck-Fächern, satter, lod1 mit Kern. Aus der Nähe
  (< 20 m) noch facettiert, aber keine „Felsbrocken“ mehr (angesehen).
- **Kuppelränder** (M3): ausgefranst, jede zweite Randecke hängt, sichtbare Kuppeln zuerst verfeinert. Im Rennbild ist
  der Unterschied bei der nahen Eiche klein: weiter ein Haufen Kuppeln wie beim Sprite, die Ränder etwas weicher
  (Bild 08). **Offen:** zwei dünne dunkle Striche oben in der Krone von `tree_oak_b` (kein Ast außerhalb der Krone,
  keine Splitterkuppel – Ursache nicht gefunden).
- **Hang** (M7): Kern mit Schürze bis 0,4 m unter den Boden (Büsche, Heide, Bodenstrauch), Gras ab −0,1 m, Felsfüße
  0,45 m im Boden; Kennzeichen `ground_align` / `ground_sink`. Die Heide hängt an 30° weiter in der Luft, bis der
  Props-Bauer Pflanzen an die Bodennormale kippt.
- **Texturbudget** (M9): Saat-Varianten zeichnen mit dem Laubatlas ihrer Art: Quellen 37,10 → 22,12 MB, Grafikspeicher
  37,37 → 25,37 MB (gemessen, `validate_models.py`).
- Gates: ⟨GATES_KURZ⟩

## 2. Die Mängel der Kritik – geprüft, behoben, vorher / nachher

Jeder Befund wurde zuerst nachgestellt (Bilder und Messzeilen der Kritik, Code, eigene Renderings auf be866d2): alle
bestätigt, keiner abgelehnt. Bei M4, M5 und M9 weicht der Weg vom Vorschlag der Kritik ab (Abschnitt 10).

| Befund | Stufe | Status | vorher (Kritik, be866d2) | nachher (gemessen / angesehen) |
|---|---|---|---|---|
| M1 Birkenstamm | hoch | **behoben** | eine Farbe je Dreieck: Schachbrett bis 40 m | Marken als Ringpaare 5–8,5 cm, Farbe je Viereck, 1–4 von 6 Segmenten; lod1 dieselben Marken (Bild 01). Schattenwerfer 196 / 220 Dreiecke (einfacher Stamm) |
| M2 Klippe | hoch | **behoben** (Modell) + Kennzeichen | aus 6 von 8 Drehungen dünne Rückseite mit Fetzen oder Horn | geschlossener Körper: Grat 1,8 m, Rückflanke, Enden zu; aus allen 8 Drehungen Fels (Bild 02); Sträucher per Strahl auf den Grat gesetzt; `face_road` im Manifest |
| M3 Kuppelränder < 25 m | mittel | **teilweise** | gerade 6–12-Eck-Kanten, Himmelslöcher, zwei Zweige über `oak_b` | Rand ±35 % / ±12 % ausgefranst, jede 2. Ecke hängt 5–10 %, Sichtbarkeits-Gewicht, Kern 0,86; Holz nur innerhalb 90 % der Kugel und 92 % der Krone (Bild 03). Im Rennbild auf dem Deck (km 54,9) bleibt die nahe Eiche ein Haufen Kuppeln wie das Sprite, mit etwas weicheren Rändern; einzelne gerade Kanten sind noch zu sehen (Bild 08, angesehen). Die zwei Striche über `oak_b` bleiben |
| M4 Büsche | mittel | **großteils** | 19–25 Kuppeln als 5–6-Eck-Fächer, Sättigung 0,34 gegen 0,42, Loch in lod1 | 15 Kuppeln mit 12-Eck-Rand, `sat` 0,72, weniger Glanz und Kontrast im Laubball, lod1 mit Kern. In 200 m war das Sprite um 21–22 % satter als der Busch, jetzt um 6–7 % weniger satt (gemessen, `bush_round` / `bush_low`). Unter 20 m bleibt der Busch facettiert (Bild 04) |
| M5 Fernbild flach | mittel | **behoben am Tag** | Kontrast −30 … −80 %, Sättigung −5 … −19 % gegen lod1 | mittags Kontrast −22 … +14 % (Palme −60 %), Sättigung −7 … +9 % (Tabelle 4.1, Bild 05); abends +10 … +121 % über lod1 (Mittagsrelief) |
| M6 Stufenwechsel | mittel | **teilweise** | 59–76 % geänderte Pixel (Laubbäume), ganze Chunks springen | lod1 auf dem Rand von lod0; Helligkeit mittags ±5 %; geänderte Pixel 63–73 % (Kiefer 34–37 %, Tabelle 4.2); der Rest ist Sache von R2/R7 (Überblendung) |
| M7 Hang | mittel | **Modellteil erledigt** | Heide, Büsche, Felsen schweben talseitig | Schürzen, Felsfüße, Gras −0,1 m; Kennzeichen für R2/R7; Heide braucht das Kippen (Bild 07) |
| M8 Palme | mittel | **behoben** | Umriss 20 % außen, Sprite zu 69 % gedeckt; `palm_b` 57 % außen; heller gestreifter Pfahl; Fernbild −16° | Sprite zu 83 % gedeckt (20 % außen); `palm_b` 27 % außen / 80 % gedeckt; dunkler Stamm ±8 %; Fernbild 512 px, Farbton −6° / −4° (Bild 06) |
| M9 Texturbudget | mittel | **behoben** | 15,8 MB byte-gleiche Atlanten | ein Atlas je Art (`variant_of`); Quellen 37,10 → 22,12 MB, Grafikspeicher 37,37 → 25,37 MB |
| M10 Olive nah | niedrig | **behoben** | Tarnmuster aus hellen Unterseiten | `underside_share` 0,15, Unterseitenfarbe näher an der Oberseite (angesehen) |
| M11 Zypresse | niedrig | **behoben** | 1 Windphase, 0 % Normalen nach oben | Phase je Ring; obere Hälfte der Flamme nach oben gekippt |
| M11 Kiefer | niedrig | **teilweise** | Stamm oben zu orange; lod1 flimmert 1,4–1,7× | Rinde oben 15 % dunkler (angesehen); lod1 flimmert eher mehr als vorher (Tabelle 4.4) |
| M11 Olive Fernbild-Stamm | niedrig | **offen** | 0,67 m in 1,5 m Höhe (lod1 0,83, Sprite 1,04) | unverändert 0,67 m (gemessen, Tabelle 4.3) |
| M11 Busch lod1-Loch | niedrig | **behoben** | dunkles Loch in 100 m | Kern auch in lod1, Kappen wie lod0 |

## 3. Was geändert ist (Aufbau)

Ausführlich in `docs/modelle.md` §15, Abschnitt „Nacharbeit nach der Kunstkritik (AS3R)“. Kurz:

- `ce3d/veg3d.py`: Birkenrinde (`_birch_marks`, `_birch_trunk`), Kuppeln (`_dome_frames`, `_rim_plan`, `_level_plans`,
  neues `_dome_cards` mit ausgefranstem, hängendem Rand aus dem eigenen Zufallsstrom der Kugel), Holz-Schnitt
  (`WOOD_HULL`, `WOOD_MASS`, `_inside_mass`), Büsche (`_merge_blobs`, `_bush_core` mit Schürze), Fernbild
  (`_relief`, Attribut `ce_nrm`, `_lit_blend` für die Fichte, `sat`, Alpha-Halo, `px`), geteilter Laubatlas
  (`_leaf_texture`), Kennzeichen (`_ground_tags`), Abgleich (`lift`, `gain`, `sat` je Art).
- `ce3d/veg3d_shapes.py`: Palmwedel (`FROND_*`), Palmstamm (`RING_LIGHT`), Zypresse (Phase je Ring, `CYPRESS_UP`).
- `ce3d/leafatlas.py`: nur `frond()` (mehr und breitere Fiedern) – `halo/bleed/coverage/png_bytes` unverändert.
- `cesprites/props_nature.py`: Hook `solid3d` der Klippe (`_cliff_solid`, `_cliff_top`) – Voreinstellung = Sprite,
  86 von 86 Sprite-Sets identisch.
- `ce3d/rock3d.py`: Sträucher auf den Fels (`_seat_shrubs`), Felsfüße (`ROCK_SINK_M`), Kennzeichen.

## 4. Messungen

### 4.1 Stufen: Helligkeit, Sättigung, Kontrast (gemessen, `kritik_scene --mode=levels`, innere Pixel)

lod0 → lod1 in 60 m, lod1 → Fernbild in 200 m, Fernbild → Arcade-Sprite in 200 m, je „vorher / nachher“ in
Prozent; alle Werte „nachher“ wurden nach den Gates auf dem Endstand ⟨HEAD⟩ gemessen. Spalte „Fernbild→Sprite“: so
viel kontrastreicher (positiv) ist das Arcade-Sprite am selben Ort als das Fernbild. Büsche und Heide haben kein
Fernbild: dort steht 0 bzw. –, und die letzte Spalte vergleicht lod1 mit dem Sprite.

Mittag:

⟨TAB_H12_LEVELS⟩

Dämmerung 19:30:

⟨TAB_H19⟩

Nacht 23 Uhr (ohne Scheinwerfer):

⟨TAB_H23⟩

⟨LESART⟩

### 4.2 Anteil geänderter Pixel beim Wechsel (gemessen, `prop_scene --mode=lods`, Σ|ΔRGB| > 0,06)

⟨TAB_UMSCHALT⟩

⟨UMSCHALT_TEXT⟩

Ein lod1 aus Fächern über den ganzen Rand von lod0 (gleiches Innen-UV) wurde gebaut und verworfen (gemessen:
Helligkeit −26 %, 15 % weniger Pixel, stachelige Kronen, Runde 1). Unsichtbar wird der Wechsel erst mit einer
Überblendung im Props-Bauer.

### 4.3 Umriss gegen das Sprite (gemessen, `kritik_scene --mode=outline`, orthografisch 6°)

„außerhalb“ = Anteil der Modellpixel außerhalb des Sprite-Umrisses, „gedeckt“ = Anteil des Sprites, den das Modell
deckt; vorher = Messung der Kritik auf be866d2 (`outline_all.log`), nachher = Endstand.

⟨TAB_UMRISS⟩

### 4.4 Flimmern (gemessen, `kritik_scene --mode=sparkle`, Anteil kippender Pixel bei ¼-Pixel-Schritten)

⟨TAB_FLIMMER⟩

Bewegt angesehen: 2-s-Fahrt mit 120 km/h an einer Baumreihe (Eiche, Birke, Buche, Pappel, Fichte, Kiefer),
120 Bilder, gerendert auf 4fb8187 (danach änderten sich nur Holz und lod1-Rand): kein Aufblitzen, keine kriechenden
Ränder (`clip_baumreihe_120kmh.mp4`, `clip_folgebilder.jpg`). Die nahe Pappel zeigt ihre Kuppeln einzeln, mit noch
eckigen Rändern (angesehen).

### 4.5 Alpha-Überzeichnung in 20 m (gemessen, `overdraw.gd` + `prop_scene --mode=lods --d0=20`)

Summe der Bildfläche aller Laub-Dreiecke von lod0 geteilt durch die gedeckten Pixel (Modell 9 m neben der Straße,
20 m voraus), gemessen auf 4fb8187. Danach änderte sich das Laub von lod0 nur bei `palm_b` (Biegung); „vorher“ =
Tabelle 4.4 von AS3.

⟨TAB_OVERDRAW⟩

### 4.6 Budget §4.6.9 (gemessen, Manifest und Dateien)

⟨TAB_BUDGET⟩

`validate_models.py --report`: ⟨VALIDATE⟩

## 5. Rennen Arcade | Modern (`tools/ab_shot.sh`, gleicher Simulationszustand)

⟨AB⟩

## 6. Gates auf dem Endstand

⟨GATES⟩

## 7. Geänderte gemeinsame Dateien (rückwärtsverträglich, additiv)

| Datei | Zweck |
|---|---|
| `tools/blender/ce3d/export.py` | ein Texturpfad mit Ordner bleibt stehen (geteilter Atlas einer Saat-Variante); ohne Ordner wie bisher |
| `tools/blender/validate_models.py` | erlaubt einer Variante (`variant_of`) die Textur ihres Art-Modells, prüft, dass es das Modell gibt, zählt die geteilte Textur nur einmal |
| `tools/blender/ce3d/catalog3d.py` | nur im Block `# --- AS3 ---`: `palm_b` Biegung 0,9; Klippe `params={"solid3d": True}`, `tags_add=["face_road"]` |
| `tools/blender/ce3d/leafatlas.py` | nur `frond()` (Palme); Halo/Bleed/Deckung unverändert (Strommast) |
| `assets/models/manifest.json` | neu erzeugt (`--manifest-only`); neue Schlüssel `variant_of`, Tags `ground_align`, `ground_sink`, `face_road` |
| `docs/modelle.md` | §15 nachgezogen, Abschnitt „Nacharbeit nach der Kunstkritik (AS3R)“ |

Eigene Dateien: `ce3d/veg3d.py`, `ce3d/veg3d_shapes.py`, `ce3d/rock3d.py`, `cesprites/props_nature.py` (Hook),
`assets/models/props/{tree_*, bush_*, cover_*, heather, rock_*, cliff}`. Nicht angefasst: Renderer, Shader,
Fahrzeuge, AS4-Dateien, Gebäude, Wahrzeichen, eingefrorene Arcade-Dateien, Sprites.

## 8. Ehrliche Einschätzung

**Gut**
- Die Birke liest sich jetzt wie eine Birke: weißer Stamm mit dunklen Querbändern, am Fuß dunkler (angesehen, 8–60 m,
  am Hang). Auf Kiel–Hamburg stehen 88 davon in den ersten 75 km.
- Die Klippe ist aus jeder Richtung ein Fels; auch quer gedreht kein Horn, keine Fetzen (angesehen, 8 Drehungen,
  Rennen Lyon–Bern).
- Die Fernbilder haben wieder Sonnenseite und Falten wie das Sprite; die Fichte zeigt ihre Etagen; im Nebel verblassen
  sie wie die Sprites (angesehen, gemessen).
- Die Palme hat eine breite, hängende Krone und einen dunklen Stamm; `palm_b` ist eine Palme wie das Sprite.
- Helligkeit beim Wechsel lod0 → lod1 überall innerhalb ±5 % (Mittag), Budgets, Arcade-Identität, Determinismus.
- 15 MB weniger Texturen, ein Atlas und ein Material je Art im Rennen.
- Im Rennen stehen Heide (Hamburg–Hannover), Oliven, Zypressen und Fichten wie ihre Sprites da, ohne Skriptfehler an
  fünf Stellen (angesehen, gemessen).

**Noch nicht gut**
- Der Stufenwechsel bei 60 m bleibt sichtbar (⟨UMSCHALT_SPANNE⟩ geänderte Pixel bei Laubbäumen) – ohne Überblendung im
  Props-Bauer nicht zu beheben.
- Nahe Laubbäume im Rennen (Eiche auf dem Deck in etwa 20 m, Pappel im Clip) bleiben ein Haufen leicht eckiger
  Laubkuppeln. Das Sprite hat dieselben Ballen, aber glatt schattiert; der Fortschritt gegenüber vorher ist dort klein
  (Bild 08).
- Büsche unter 20 m: weiter leicht facettierte, große Kuppeln mit deutlichem Blattmuster; das Sprite zeigt mehr und
  kleinere Ballen.
- `tree_oak_b`: zwei dünne dunkle Striche oben in der Krone (aus der Nähe, < 20 m) – Ursache nicht gefunden.
- Kiefer flimmert in lod1 bei 80–150 m deutlich mehr als ihr Sprite (dünne Polster, Tabelle 4.4).
- Abends und nachts tragen die Fernbilder ihr Mittagsrelief (Kontrast über lod1, Tabelle 4.1); nachts sind einige um
  wenige Grauwerte heller als lod1.
- Olive: Fernbild-Stamm schmaler als lod1 (Tabelle 4.3).
- Eine quer gestellte Klippe ist von der Schmalseite schmaler als das Sprite (Rennen Lyon–Bern), bis R2/R7
  `face_road` auswerten.
- Heide am 30°-Hang: die Talseite hängt weiter in der Luft (braucht `ground_align` im Props-Bauer).

**Fehlt**
- Schnee- und Nässe-Darstellung (nur Normalen; Zypresse jetzt mit nach oben zeigender Spitze) – R4.
- Ein eigenes Fernbild oder Stufen für Felsen und Klippe (automatische Netz-Stufen).

## 9. Hinweise für R2 / R7 / R4 und Folgepakete

1. **Props-Bauer – Kennzeichen lesen:** `face_road` (Klippe: Schauseite zur Straße, höchstens ±20° drehen – eine quer
   gestellte 26-m-Klippe reicht sonst bis etwa 3 m an die Fahrbahn, gefolgert); `ground_align` (Heide, Büsche,
   Bodendecker: an die Bodennormale kippen wie den Kontaktschatten); `ground_sink` (Felsen, Klippe: auf den tiefsten
   Bodenpunkt der Grundfläche setzen). Alle drei stehen in `tags` des Manifests.
2. **Props-Bauer – Überblendung beim Stufenwechsel** (0,3–0,5 s Dither wie die Fahrzeugstufen); der Wechsel wird heute
   je 96-m-Chunk für alle Bäume im selben Bild gemacht.
3. **Fernbild:** braucht kein `baked_light` – das Relief steckt im Albedo und wird mit dem bisherigen Gesetz von
   `billboard.gdshader` gezeigt. Für Dämmerung und Nacht wäre ein Faktor je Tageszeit auf dem Relief nötig (das
   Fernbild trägt das Mittagslicht).
4. **Atlas-Teilung:** ModelDB und ModernMaterials brauchten nichts; wer Varianten in Fixtures kopiert, muss den Atlas
   der Art mitkopieren (`variant_of`).
5. **R2-Test:** `tests/unit/race3d/test_props.gd` nimmt `props/tree_beech` als Set ohne Modell (seit AS3 rot);
   Vorschlag von AS3 liegt in `deliver/AS3/vorschlag_test_props_fuer_R2.diff`. Solange er rot ist, überspringt
   `run_tests.sh` alle Integrationsszenarien und Modern-Checks.
6. **AS3-Folgearbeit:** nahe Laubkuppeln im Rennbild (z. B. mehr Kronenrundung `crown_w` in den Eckennormalen, damit
   die Ballen weniger einzeln wirken – nicht ausprobiert), Büsche unter 20 m (mehr, kleinere Ballen), die zwei
   Striche in `tree_oak_b`, das Flimmern der Kiefer in lod1, der Olivenstamm im Fernbild, der Kontrast des
   Palmen-Fernbilds.
7. **R4 (Schnee, Nässe):** die Zypresse hat jetzt nach oben gekippte Normalen in der oberen Hälfte; Heide und Büsche
   unverändert.
8. **Werkzeug:** Die Messmodi der Kritik (`kritik_scene.gd`: levels, outline, sparkle, slope, turn, under) habe ich
   als unversionierte Kopie benutzt und gelöscht; für weitere Kunstprüfungen wären sie in `tools/models/` gut
   aufgehoben.

## 10. Abweichungen

⟨ABW⟩

## 11. Bilder in diesem Ordner

| Datei | Inhalt |
|---|---|
| `01_birkenstamm_vorher_nachher.jpg` | Birke vorher (Kritik) und nachher in 8 / 12 / 25 m neben dem Sprite, Fuß am 30°-Hang 4× |
| `02_klippe_vorher_nachher.jpg` | Klippe in 8 Drehungen, vorher / nachher |
| `03_kronen_nah_vorher_nachher.jpg` | Kronen aus 15 m von unten, vorher / nachher (Eiche_b, Buche, Eiche) |
| `04_buesche_vorher_nachher.jpg` | Büsche vorher / nachher in 15–250 m neben dem Sprite |
| `05_fernbild_vorher_nachher.jpg` | Stufen lod0/lod1 in 60 m, lod1/Fernbild/Sprite in 200 m, vorher / nachher |
| `06_palme_vorher_nachher.jpg` | Palme und `palm_b` vorher / nachher in 15–250 m |
| `07_hang_30grad_nachher.jpg` | Birke, Palme, Büsche, Heide, Gras, Felsen am 30°-Hang, Fuß 4× |
| `08_rennen_modern_vorher_nachher.jpg` | Modern im Rennen vorher (be866d2, Bilder der Kritik) und nachher am selben Simulationszustand: Kiel–Hamburg km 54,9 (Deck), Barcelona–Montpellier km 42,7 (Hoch), je mit Vergrößerung |
| `kontakt_mittag_1.jpg` … `_6.jpg` | alle Modelle in 15 / 40 / 100 / 250 m neben ihrem Arcade-Sprite, Mittag, Renn-Licht (Endstand) |
| `daemmerung.jpg`, `nacht.jpg` | Eiche, Birke, Fichte, Palme, Busch um 19:30 und 23 Uhr (Endstand) |
| `stufen_mittag.jpg` | alle Bäume: lod0/lod1 in 60 m, lod1/Fernbild/Sprite in 200 m, Mittag (Endstand) |
| `umrisse_gegen_sprite.jpg` | Umriss jedes Baums (lod0, lod1, Fernbild) über dem Sprite-Umriss (Endstand) |
| `fernbild_im_nebel.jpg` | Fernbild und Sprite in 300 / 500 / 700 / 850 m (4fb8187) |
| `clip_baumreihe_120kmh.mp4`, `clip_folgebilder.jpg` | 2 s bei 120 km/h an einer Baumreihe, vier Folgebilder (4fb8187) |
| `ab_kh54_hoch_00/01.jpg`, `ab_kh54_deck_00/01.jpg`, `ab_bm42_hoch_00/01.jpg`, `ab_lb148_hoch_00/01.jpg`, `ab_hh47_mittel_00.jpg` | Rennen Arcade \| Modern (Abschnitt 5) |
