# AS3R – Nacharbeit Vegetation und Natur nach der Kunstkritik (Bericht)

- Zweig `worktree-wf_aad8d49e-fb4-4`, Arbeitsbaum `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_aad8d49e-fb4-4`,
  Sicherung `origin/wip/v080-as3r` (nach jedem Commit gepusht). Basis **be866d2** (AS3, ff-merge), Endstand **638debc**.
- Commits: aee59b8 (Runde 1), 4fb8187 (Runden 2–5: lod1, Fernbild, Abgleich), 638debc (Holz, voller lod1-Rand, palm_b,
  Doku); danach kein Commit (Bericht und Bilder liegen nur in diesem Ordner).
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
- Gates: Sprite-Geometrie 86/86 identisch, Cache-Schlüssel OK, erzwungener Export byte-gleich, Prüfer OK, alle
  Budgets eingehalten, fünf A/B-Rennen ohne Skriptfehler, Arcade-Bilder 20 von 20 identisch. `run_tests.sh` ist rot,
  aber nur mit den zwei bekannten Tests des Props-Bauers (R2), die seit AS3 rot sind: 692 Tests, 2 fehlgeschlagen
  (Abschnitt 6).

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
Prozent; alle Werte „nachher“ wurden nach den Gates auf dem Endstand 638debc gemessen. Spalte „Fernbild→Sprite“: so
viel kontrastreicher (positiv) ist das Arcade-Sprite am selben Ort als das Fernbild. Büsche und Heide haben kein
Fernbild: dort steht 0 bzw. –, und die letzte Spalte vergleicht lod1 mit dem Sprite.

Mittag:

| Modell | lod0→lod1 Helligkeit vorher / nachher | lod1→Fernbild Helligkeit | Sättigung | Kontrast | Fernbild→Sprite Kontrast |
|---|---|---|---|---|---|
| tree_oak | +0.1 / +0.4 | -3.0 / -1.7 | -8.8 / +3.9 | -32.4 / +4.2 | +35.9 / -11.7 |
| tree_oak_b | +4.2 / -0.0 | -5.4 / +1.3 | -8.2 / +3.7 | -32.2 / +2.7 | +28.7 / -14.7 |
| tree_birch | +1.5 / +1.9 | +3.7 / +0.5 | -19.2 / +0.0 | -38.2 / +1.5 | +70.6 / -1.0 |
| tree_birch_b | -0.6 / -2.1 | +3.5 / +0.8 | -16.9 / +8.9 | -47.3 / -4.7 | +96.5 / +5.5 |
| tree_beech | -2.9 / -3.0 | +3.7 / +3.5 | -7.5 / +9.1 | -31.4 / +13.5 | +47.0 / -11.6 |
| tree_beech_b | -1.6 / +1.5 | +2.0 / +0.4 | -7.0 / +5.7 | -29.6 / -0.3 | +48.9 / -4.0 |
| tree_poplar | +0.3 / +0.2 | -2.6 / -1.0 | -8.4 / +2.3 | -47.6 / -14.2 | +41.0 / -2.8 |
| tree_poplar_b | +3.6 / +1.5 | -5.2 / -1.0 | -9.3 / +1.1 | -45.8 / -16.6 | +40.5 / -2.9 |
| tree_olive | -3.1 / -1.9 | +2.2 / +5.0 | -14.9 / +4.9 | -44.4 / +12.6 | +52.4 / -17.3 |
| tree_olive_b | -1.8 / +5.0 | +1.1 / -8.7 | -9.3 / +8.2 | -32.0 / +12.7 | +26.9 / -20.4 |
| tree_pine | +2.0 / +1.9 | +1.1 / -2.0 | -5.1 / +4.8 | -35.1 / -4.9 | +14.7 / -28.8 |
| tree_pine_b | +0.9 / +1.5 | +1.0 / -8.0 | -5.3 / +5.1 | -41.6 / -0.5 | +14.4 / -22.9 |
| tree_spruce | +1.8 / +1.8 | -8.2 / -4.2 | -17.7 / -6.7 | -64.9 / -21.6 | +172.0 / +21.9 |
| tree_spruce_b | +3.1 / +3.1 | -10.8 / -5.3 | -16.0 / -5.3 | -65.7 / -19.1 | +169.7 / +14.4 |
| tree_cypress | -1.9 / -1.9 | -2.0 / -2.4 | -5.2 / +2.1 | -47.7 / +3.1 | +113.0 / +0.4 |
| tree_cypress_b | -1.8 / -1.7 | -2.6 / -3.5 | -8.1 / +8.8 | -47.5 / +4.3 | +106.0 / +3.2 |
| tree_palm | -0.1 / +1.8 | -4.0 / +6.3 | +12.8 / +4.4 | -70.4 / -61.8 | +117.6 / +107.1 |
| tree_palm_b | +0.5 / +0.5 | +1.3 / +3.0 | +6.6 / +7.9 | -79.9 / -58.8 | +286.7 / +114.7 |
| bush_round | +0.1 / -3.3 | +0.0 / +0.0 | +0.0 / +0.0 | +0.0 / +0.0 | -19.1 / -15.6 |
| bush_low | +1.9 / -3.5 | +0.0 / +0.0 | +0.0 / +0.0 | +0.0 / +0.0 | -14.0 / -14.0 |
| heather | -1.2 / -3.6 | – / – | – / – | – / – | – / – |

Dämmerung 19:30:

| Modell | lod0→lod1 Helligkeit vorher / nachher | lod1→Fernbild Helligkeit | Sättigung | Kontrast | Fernbild→Sprite Kontrast |
|---|---|---|---|---|---|
| tree_oak | +2.8 / +3.1 | -3.4 / -1.6 | -14.0 / -5.3 | -19.3 / +25.9 | +10.2 / -28.1 |
| tree_oak_b | +6.3 / +1.8 | -5.6 / +2.5 | -14.2 / -4.0 | -14.8 / +29.5 | +4.6 / -30.1 |
| tree_birch | +3.1 / +3.2 | +4.4 / +1.5 | -17.5 / -8.4 | -16.9 / +36.7 | +36.4 / -21.2 |
| tree_birch_b | +0.1 / -0.5 | +3.5 / -0.5 | -18.1 / -7.3 | -25.1 / +19.6 | +56.9 / -15.8 |
| tree_beech | -1.4 / -1.7 | +2.9 / +3.3 | -11.4 / +1.9 | -12.3 / +34.6 | +16.9 / -28.0 |
| tree_beech_b | -0.6 / +2.6 | +3.4 / +2.6 | -11.1 / -1.6 | -5.3 / +30.8 | +18.6 / -23.1 |
| tree_poplar | +3.2 / +2.9 | -4.4 / -2.9 | -13.9 / -5.3 | -36.3 / +11.7 | +14.0 / -22.0 |
| tree_poplar_b | +4.8 / +3.5 | -5.1 / -1.8 | -13.9 / -5.8 | -32.3 / +10.4 | +12.8 / -22.3 |
| tree_olive | -2.0 / -0.4 | +3.8 / +7.0 | -11.1 / -4.8 | -28.7 / +38.2 | +21.5 / -33.7 |
| tree_olive_b | -0.7 / +6.5 | +0.1 / -10.7 | -9.2 / -4.4 | -11.2 / +47.9 | +1.4 / -35.9 |
| tree_pine | +2.1 / +2.6 | +1.2 / -0.7 | -7.1 / +1.9 | -20.3 / +20.6 | -4.3 / -39.5 |
| tree_pine_b | +1.2 / +1.6 | +0.4 / -7.3 | -9.7 / -0.4 | -28.5 / +21.1 | -4.7 / -33.6 |
| tree_spruce | +4.3 / +4.3 | +6.1 / +11.7 | -33.6 / -35.6 | -66.2 / -24.8 | +123.8 / +0.7 |
| tree_spruce_b | +5.8 / +5.8 | +2.0 / +9.6 | -36.8 / -37.2 | -66.9 / -21.8 | +123.4 / -5.3 |
| tree_cypress | -2.6 / -2.7 | +3.9 / +4.8 | -25.5 / -17.8 | +9.5 / +120.8 | +81.7 / -14.3 |
| tree_cypress_b | -2.7 / -2.6 | +3.3 / +3.0 | -25.8 / -21.2 | +11.5 / +114.2 | +73.6 / -10.0 |
| tree_palm | -0.9 / +1.9 | -0.2 / +13.4 | -9.2 / -11.8 | -68.2 / -60.9 | +66.3 / +63.7 |
| tree_palm_b | -0.8 / -0.2 | +7.7 / +8.2 | -14.9 / -10.7 | -77.5 / -55.1 | +193.5 / +71.7 |
| bush_round | +4.6 / +0.7 | +0.0 / +0.0 | +0.0 / +0.0 | +0.0 / +0.0 | -29.7 / -21.4 |
| bush_low | +6.7 / +0.7 | +0.0 / +0.0 | +0.0 / +0.0 | +0.0 / +0.0 | +8.6 / -20.2 |
| heather | -1.6 / -1.3 | – / – | – / – | – / – | – / – |

Nacht 23 Uhr (ohne Scheinwerfer):

| Modell | lod0→lod1 Helligkeit vorher / nachher | lod1→Fernbild Helligkeit | Sättigung | Kontrast | Fernbild→Sprite Kontrast |
|---|---|---|---|---|---|
| tree_oak | +2.8 / +3.4 | -1.2 / +1.6 | -8.5 / +6.2 | -20.4 / +26.9 | +14.2 / -27.5 |
| tree_oak_b | +7.9 / +3.0 | -3.5 / +6.9 | -4.5 / -1.0 | -15.1 / +25.3 | +7.7 / -29.6 |
| tree_birch | +3.3 / +4.0 | +8.7 / +5.4 | -24.0 / -9.7 | -3.4 / +50.9 | +25.4 / -26.0 |
| tree_birch_b | +0.4 / -0.7 | +7.9 / +7.7 | -21.5 / -6.8 | -16.4 / +62.4 | +43.7 / -20.9 |
| tree_beech | -1.9 / -1.6 | +6.4 / +7.2 | -12.8 / -4.7 | -13.9 / +33.4 | +19.9 / -28.2 |
| tree_beech_b | -0.9 / +4.2 | +6.4 / +5.1 | -11.1 / +2.5 | -4.2 / +32.7 | +20.9 / -23.4 |
| tree_poplar | +4.3 / +3.9 | -1.7 / +0.4 | -14.8 / +3.7 | -38.3 / +14.3 | +16.9 / -22.4 |
| tree_poplar_b | +7.0 / +4.7 | -3.7 / +1.9 | -11.6 / +0.4 | -34.1 / +11.9 | +15.4 / -22.8 |
| tree_olive | -2.4 / -0.4 | +3.5 / +9.3 | +6.7 / -2.4 | -28.6 / +36.0 | +15.1 / -35.5 |
| tree_olive_b | -1.1 / +8.3 | +1.4 / -10.4 | +2.3 / +4.7 | -12.5 / +42.8 | -2.9 / -37.1 |
| tree_pine | +2.1 / +3.0 | +8.3 / +2.2 | -13.1 / -27.3 | -14.5 / +30.4 | +3.1 / -39.3 |
| tree_pine_b | +1.0 / +1.9 | +10.2 / -3.9 | -4.4 / -22.2 | -21.8 / +43.6 | +3.5 / -33.2 |
| tree_spruce | +5.9 / +5.9 | +25.7 / +32.1 | -29.4 / -20.6 | -26.7 / +43.7 | +117.4 / +10.9 |
| tree_spruce_b | +8.1 / +8.1 | +20.5 / +29.6 | -24.5 / -18.8 | -23.7 / +56.1 | +117.1 / +6.1 |
| tree_cypress | -3.4 / -3.4 | +19.4 / +18.1 | -23.6 / -18.0 | +19.9 / +97.9 | +47.1 / -18.9 |
| tree_cypress_b | -3.7 / -3.6 | +18.5 / +17.0 | -23.0 / -15.5 | +28.8 / +106.7 | +41.5 / -12.9 |
| tree_palm | -0.0 / +1.8 | +10.0 / +20.3 | -24.6 / -17.5 | +0.6 / -5.8 | +64.6 / +63.4 |
| tree_palm_b | -0.8 / +0.3 | +14.7 / +14.2 | -23.0 / -15.8 | -34.6 / -12.9 | +190.6 / +76.5 |
| bush_round | +6.8 / +1.7 | +0.0 / +0.0 | +0.0 / +0.0 | +0.0 / +0.0 | -30.2 / -22.1 |
| bush_low | +11.3 / -0.5 | +0.0 / +0.0 | +0.0 / +0.0 | +0.0 / +0.0 | +5.1 / +37.5 |
| heather | -0.4 / -1.8 | – / – | – / – | – / – | – / – |

Lesart (gemessen, Endstand):

- **Mittags** liegt jedes Fernbild außer der Palme bei lod1: Kontrast −22 … +14 % (die Kritik maß −30 … −80 %),
  Sättigung −7 … +9 % (vorher −5 … −19 %), Helligkeit −9 … +6 %. Das Arcade-Sprite ist nicht mehr deutlich
  kontrastreicher als das Fernbild (−29 … +22 % statt +14 … +290 %). Die Palme bleibt bei −59 … −62 % Kontrast: ihre
  dünnen Wedel lösen sich im Fernbild kaum auf.
- **lod0 → lod1** springt die Helligkeit mittags um −3,6 … +5,0 % (alle 21 Modelle), abends um −2,7 … +6,5 %, nachts
  um −3,6 … +8,3 %. Ausreißer ist `olive_b`: +5,0 / +6,5 / +8,3 % (vorher −1,8 / −0,7 / −1,1 %), seit ihr lod1 den
  vollen Kuppelrand trägt; `spruce_b` hat nachts +8,1 % wie vorher. Alle anderen bleiben innerhalb ±6 %.
- **Abends (19:30)** zeigt das Fernbild weiter das Relief aus dem Licht des Sprite-Rigs, lod1 dagegen das flache
  Abendlicht. Deshalb liegt der Kontrast der Laubbäume und Kiefern +10 … +48 % über lod1 und der der Zypresse +114 … +121 %
  (vorher −5 … −36 % bzw. +9,5 … +11,5 %). Das Arcade-Sprite hat dann bis zu 40 % weniger Kontrast als das Fernbild
  (Fichte gleich viel; vorher bis zu 124 % mehr). Die Fichte verliert abends wie vorher rund ein Drittel der Sättigung (−36 %).
- **Nachts** sind die Fernbilder von Fichte (+30 / +32 %), Palme (+14 / +20 %) und Zypresse (+17 / +18 %) heller
  als lod1. Bei einer Krone um 10–30 von 255 Grauwerten (Messung von AS3) sind das 2–6 Grauwerte; das Gesetz von
  `billboard.gdshader` ist unverändert.
- Abhilfe für Abend und Nacht wäre ein Tageszeit-Faktor auf dem eingebackenen Relief im Shader (R2/R7, Abschnitt 9).

### 4.2 Anteil geänderter Pixel beim Wechsel (gemessen, `prop_scene --mode=lods`, Σ|ΔRGB| > 0,06)

| Modell | lod0→lod1 geänderte Pixel vorher / nachher | lod1→Fernbild geänderte Pixel vorher / nachher |
|---|---|---|
| tree_oak | 68 / 69.0 % | 77 / 77.8 % |
| tree_oak_b | 67 / 67.2 % | 77 / 76.5 % |
| tree_birch | 68 / 64.8 % | 97 / 77.5 % |
| tree_birch_b | 66 / 68.5 % | 96 / 87.7 % |
| tree_beech | 59 / 63.1 % | 80 / 77.4 % |
| tree_beech_b | 59 / 66.2 % | 79 / 72.4 % |
| tree_poplar | 76 / 70.3 % | 81 / 76.7 % |
| tree_poplar_b | 74 / 73.0 % | 82 / 74.3 % |
| tree_olive | 62 / 70.4 % | 85 / 81.0 % |
| tree_olive_b | 62 / 67.0 % | 85 / 81.9 % |
| tree_pine | 43 / 34.3 % | 85 / 85.9 % |
| tree_pine_b | 44 / 36.6 % | 86 / 82.5 % |
| tree_spruce | 61 / 60.6 % | 68 / 83.4 % |
| tree_spruce_b | 63 / 62.7 % | 71 / 82.0 % |
| tree_cypress | 36 / 36.9 % | 59 / 45.8 % |
| tree_cypress_b | 36 / 37.2 % | 63 / 51.1 % |
| tree_palm | 34 / 28.6 % | 99 / 88.1 % |
| tree_palm_b | 34 / 28.4 % | 98 / 90.4 % |

„vorher“ = Tabelle 4.3 von AS3 auf be866d2 (dasselbe Werkzeug, dieselbe Stelle). Beim Wechsel lod0 → lod1 ändern sich
bei den Laubbäumen weiter 63–73 % der Pixel (vorher 59–76 %). Bei der Kiefer sind es 34–37 % (vorher 43–44 %), bei der
Palme 28 % (vorher 34 %). Die Helligkeit bleibt (4.1). Rand und Texturlage der Kuppeln sind in beiden Stufen gleich,
das Innere jeder Kuppel (Wölbung, Kern) aber nicht. Beim Wechsel zum Fernbild sind es 72–90 % (Zypresse 46–51 %; Birke
97 → 78 %, Palme 99 → 88 %). Bei der Fichte sind es 82–83 % statt 68–71 %, weil ihr Fernbild jetzt eigene Etagenschatten trägt.

Ein lod1 aus Fächern über den ganzen Rand von lod0 (gleiches Innen-UV) wurde gebaut und verworfen (gemessen:
Helligkeit −26 %, 15 % weniger Pixel, stachelige Kronen, Runde 1). Unsichtbar wird der Wechsel erst mit einer
Überblendung im Props-Bauer.

### 4.3 Umriss gegen das Sprite (gemessen, `kritik_scene --mode=outline`, orthografisch 6°)

„außerhalb“ = Anteil der Modellpixel außerhalb des Sprite-Umrisses, „gedeckt“ = Anteil des Sprites, den das Modell
deckt; vorher = Messung der Kritik auf be866d2 (`outline_all.log`), nachher = Endstand.

| Modell | lod0 außerhalb / Sprite gedeckt vorher | nachher | Fernbild vorher | nachher | Stamm 1,5 m lod1 / Fernbild / Sprite nachher |
|---|---|---|---|---|---|
| tree_oak | 2,0 / 98,5 % | 2,4 / 98,8 % | 3,5 / 98,2 % | 4,1 / 98,5 % | 0,71 / 0,71 / 0,71 m |
| tree_oak_b | 9,1 / 83,5 % | 8,2 / 84,0 % | 8,8 / 82,6 % | 8,1 / 83,2 % | 0,71 / 0,71 / 0,71 m |
| tree_birch | 3,9 / 96,3 % | 4,1 / 95,9 % | 4,4 / 96,4 % | 4,9 / 96,6 % | 0,33 / 0,33 / 0,38 m |
| tree_birch_b | 18,8 / 79,8 % | 19,3 / 80,3 % | 18,6 / 79,8 % | 19,2 / 81,0 % | 0,33 / 0,33 / 0,38 m |
| tree_beech | 0,8 / 98,3 % | 1,2 / 98,7 % | 0,9 / 97,4 % | 1,4 / 97,9 % | 0,58 / 0,58 / 0,58 m |
| tree_beech_b | 7,7 / 92,0 % | 7,7 / 91,8 % | 7,5 / 90,7 % | 7,6 / 90,6 % | 0,58 / 0,58 / 0,58 m |
| tree_poplar | 5,6 / 98,5 % | 5,5 / 98,8 % | 5,3 / 98,8 % | 5,2 / 98,9 % | 0,54 / 0,54 / 0,54 m |
| tree_poplar_b | 14,3 / 87,3 % | 15,1 / 88,0 % | 14,3 / 86,7 % | 15,1 / 87,5 % | 0,54 / 0,62 / 0,54 m |
| tree_olive | 2,2 / 98,6 % | 2,5 / 98,7 % | 3,7 / 96,5 % | 3,8 / 97,0 % | 0,83 / 0,67 / 1,04 m |
| tree_olive_b | 10,2 / 84,6 % | 9,7 / 84,5 % | 9,1 / 85,5 % | 8,9 / 85,8 % | 0,92 / 1,38 / 1,04 m |
| tree_pine | 3,0 / 95,9 % | 2,6 / 95,7 % | 4,6 / 93,0 % | 4,6 / 93,3 % | 0,58 / 0,58 / 0,58 m |
| tree_pine_b | 17,3 / 84,1 % | 17,9 / 84,0 % | 18,4 / 82,8 % | 19,2 / 83,1 % | 0,58 / 0,58 / 0,58 m |
| tree_spruce | 9,0 / 88,9 % | 9,0 / 88,9 % | 7,9 / 87,3 % | 8,2 / 87,6 % | 5,29 / 5,25 / 6,04 m |
| tree_spruce_b | 10,0 / 77,4 % | 10,0 / 77,4 % | 7,8 / 76,1 % | 8,0 / 76,6 % | 6,21 / 6,21 / 6,04 m |
| tree_cypress | 0,8 / 96,5 % | 0,9 / 96,5 % | 0,9 / 96,4 % | 1,4 / 97,0 % | 1,08 / 1,25 / 1,25 m |
| tree_cypress_b | 0,9 / 73,7 % | 0,9 / 73,7 % | 0,5 / 73,3 % | 1,0 / 74,4 % | 1,17 / 1,29 / 1,25 m |
| tree_palm | 20,0 / 69,3 % | 20,3 / 82,9 % | 20,1 / 65,9 % | 18,3 / 81,1 % | 0,42 / 0,50 / 0,46 m |
| tree_palm_b | 57,1 / 38,5 % | 26,8 / 79,6 % | 60,6 / 34,1 % | 28,7 / 77,5 % | 0,42 / 0,50 / 0,46 m |

### 4.4 Flimmern (gemessen, `kritik_scene --mode=sparkle`, Anteil kippender Pixel bei ¼-Pixel-Schritten)

| Modell | 40 / 80 / 150 m vorher | nachher | Arcade-Sprite |
|---|---|---|---|
| tree_oak | 0.7 / 1.6 / 2.8 | 0.7 / 1.7 / 3.3 | 0.6 / 1.1 / 2.0 |
| tree_birch | 1.2 / 3.1 / 6.0 | 1.0 / 3.1 / 5.7 | 1.6 / 3.1 / 5.4 |
| tree_poplar | 0.9 / 2.3 / 4.5 | 0.8 / 2.2 / 4.4 | 0.9 / 1.9 / 3.4 |
| tree_spruce | 1.8 / 2.9 / 5.0 | 1.8 / 2.9 / 5.0 | 1.1 / 2.1 / 3.8 |
| tree_pine | 1.9 / 6.1 / 10.5 | 2.3 / 6.6 / 12.5 | 1.9 / 3.7 / 7.5 |
| tree_palm | 4.1 / 10.5 / 13.9 | 4.4 / 12.0 / 16.7 | 5.5 / 8.4 / 12.4 |

Bewegt angesehen: 2-s-Fahrt mit 120 km/h an einer Baumreihe (Eiche, Birke, Buche, Pappel, Fichte, Kiefer),
120 Bilder, gerendert auf 4fb8187 (danach änderten sich nur Holz und lod1-Rand): kein Aufblitzen, keine kriechenden
Ränder (`clip_baumreihe_120kmh.mp4`, `clip_folgebilder.jpg`). Die nahe Pappel zeigt ihre Kuppeln einzeln, mit noch
eckigen Rändern (angesehen).

### 4.5 Alpha-Überzeichnung in 20 m (gemessen, `overdraw.gd` + `prop_scene --mode=lods --d0=20`)

Summe der Bildfläche aller Laub-Dreiecke von lod0 geteilt durch die gedeckten Pixel (Modell 9 m neben der Straße,
20 m voraus), gemessen auf 4fb8187. Danach änderte sich das Laub von lod0 nur bei `palm_b` (Biegung); „vorher“ =
Tabelle 4.4 von AS3.

| Modell | Kuppeln/Karten lod0 | Laub-Dreiecke lod0 | Laubfläche (px) | gedeckte Pixel | Überzeichnung nachher (vorher AS3) |
|---|---|---|---|---|---|
| tree_oak | 67 | 2108 | 662 739 | 121 290 | 5.5× (5.3×) |
| tree_oak_b | 67 | 2180 | 689 618 | 116 157 | 5.9× (5.8×) |
| tree_birch | 33 | 1440 | 124 337 | 40 231 | 3.1× (3.1×) |
| tree_birch_b | 34 | 1272 | 126 661 | 39 261 | 3.2× (3.3×) |
| tree_beech | 62 | 2108 | 659 742 | 95 326 | 6.9× (6.7×) |
| tree_beech_b | 62 | 2132 | 656 496 | 98 299 | 6.7× (6.5×) |
| tree_poplar | 82 | 2228 | 475 465 | 48 208 | 9.9× (9.7×) |
| tree_poplar_b | 80 | 2204 | 439 252 | 46 589 | 9.4× (9.2×) |
| tree_olive | 40 | 1940 | 186 293 | 38 142 | 4.9× (4.8×) |
| tree_olive_b | 39 | 1892 | 181 175 | 35 793 | 5.1× (5.0×) |
| tree_pine | 30 | 1440 | 131 407 | 18 353 | 7.2× (7.1×) |
| tree_pine_b | 36 | 1728 | 157 091 | 18 297 | 8.6× (8.5×) |
| tree_spruce | 270 | 1026 | 579 787 | 66 867 | 8.7× (8.7×) |
| tree_spruce_b | 216 | 822 | 455 347 | 61 907 | 7.4× (7.4×) |
| tree_cypress | 0 | 1200 | 43 829 | 23 305 | 1.9× (1.9×) |
| tree_cypress_b | 0 | 1200 | 33 153 | 17 947 | 1.8× (1.8×) |
| tree_palm | 208 | 416 | 36 138 | 21 924 | 1.6× (1.5×) |
| tree_palm_b | 208 | 416 | 36 374 | 21 828 | 1.7× (1.5×) |
| bush_round | 15 | 380 | 50 355 | 10 277 | 4.9× (4.3×) |
| bush_round_b | 15 | 380 | 55 803 | 10 598 | 5.3× (4.9×) |
| bush_low | 15 | 380 | 33 529 | 9 546 | 3.5× (3.7×) |
| cover_bush | 9 | 380 | 4 881 | 884 | 5.5× (4.3×) |
| heather | 30 | 396 | 20 397 | 5 091 | 4.0× (3.4×) |

### 4.6 Budget §4.6.9 (gemessen, Manifest und Dateien)

| Modell | Art | Dreiecke lod0 / lod1 | Kuppeln bzw. Karten lod0 / lod1 | Aufrufe lod0 / lod1 / Fernbild | Schatten | Netze B | Texturen B (Quelle) | Budget |
|---|---|---|---|---|---|---|---|---|
| bush_low | plant | 380 / 116 | 15 / 15 | 1 / 1 | – | 11 753 | 440 376 | 400 / 120, 1 |
| bush_round | plant | 380 / 116 | 15 / 15 | 1 / 1 | – | 11 706 | 437 884 | 400 / 120, 1 |
| bush_round_b | plant | 380 / 116 | 15 / 15 | 1 / 1 | – | 11 767 | 0 | 400 / 120, 1 |
| cliff | rock | 5799 | – | 1 | – | 113 957 | 999 334 | 6 000 / auto, 1 |
| cover_bush | plant | 380 / 116 | 9 / 9 | 1 / 1 | – | 10 434 | 439 283 | 400 / 120, 1 |
| cover_grass | plant | 84 / 28 | 42 / 14 | 1 / 1 | – | 4 368 | 299 568 | 400 / 120, 1 |
| heather | plant | 396 / 118 | 30 / 30 | 1 / 1 | – | 13 263 | 455 522 | 400 / 120, 1 |
| rock_a | rock | 640 | – | 1 | – | 11 374 | 157 072 | 1 500 / auto, 1 |
| rock_b | rock | 960 | – | 1 | – | 17 435 | 175 163 | 1 500 / auto, 1 |
| tree_beech | tree | 2475 / 882 | 62 / 62 | 2 / 2 / 1 | 186 | 64 988 | 1 990 252 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_beech_b | tree | 2466 / 883 | 62 / 62 | 2 / 2 / 1 | 175 | 64 537 | 107 246 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_birch | tree | 2457 / 890 | 33 / 33 | 2 / 2 / 1 | 196 | 57 983 | 2 011 982 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_birch_b | tree | 2465 / 890 | 34 / 34 | 2 / 2 / 1 | 220 | 58 240 | 113 392 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_cypress | tree | 1236 / 316 | 0 / 0 | 2 / 2 / 1 | 128 | 41 030 | 1 744 862 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_cypress_b | tree | 1236 / 316 | 0 / 0 | 2 / 2 / 1 | 128 | 40 734 | 34 823 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_oak | tree | 2466 / 889 | 67 / 67 | 2 / 2 / 1 | 175 | 65 960 | 1 954 252 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_oak_b | tree | 2461 / 888 | 67 / 67 | 2 / 2 / 1 | 192 | 67 295 | 72 513 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_olive | tree | 2271 / 890 | 40 / 40 | 2 / 2 / 1 | 242 | 61 247 | 2 013 506 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_olive_b | tree | 2154 / 885 | 39 / 39 | 2 / 2 / 1 | 225 | 58 930 | 55 523 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_palm | tree | 1184 / 714 | 208 / 104 | 2 / 2 / 1 | – | 27 121 | 686 940 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_palm_b | tree | 1184 / 714 | 208 / 104 | 2 / 2 / 1 | – | 26 985 | 59 475 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_pine | tree | 1684 / 832 | 30 / 30 | 2 / 2 / 1 | 192 | 46 247 | 2 153 411 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_pine_b | tree | 1959 / 880 | 36 / 36 | 2 / 2 / 1 | 192 | 51 801 | 44 240 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_poplar | tree | 2462 / 886 | 82 / 82 | 2 / 2 / 1 | 136 | 68 532 | 1 959 449 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_poplar_b | tree | 2470 / 886 | 80 / 80 | 2 / 2 / 1 | 136 | 67 755 | 89 972 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_spruce | tree | 1062 / 462 | 270 / 90 | 2 / 2 / 1 | 282 | 58 016 | 1 319 904 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |
| tree_spruce_b | tree | 858 / 378 | 216 / 72 | 2 / 2 / 1 | 234 | 47 278 | 90 010 | 2 500 / 900 / Fernbild, ≤ 450 Karten, 2/2/1 |

Summe der 27 Modelle: Netze 1.18 MB, Texturquellen 19.91 MB

`validate_models.py --report`: `CHECK models OK` (gemessen auf dem Endstand nach der Determinismus-Probe); ganzer Satz 46 Modelle, Netze 5,27 von
40 MB, Texturen 25,37 von 240 MB im Grafikspeicher (vorher 37,37 MB), Quellen 22,12 von 60 MB (vorher 37,10 MB).
Die 27 AS3-Modelle: Netze 1,18 MB, Texturquellen 19,91 MB (vorher 35,6 MB). Die Varianten zeigen 0 bis 113 kB
eigene Texturen (nur ihr Fernbild); den Laubatlas teilen sie mit ihrer Art.

## 5. Rennen Arcade | Modern (`tools/ab_shot.sh`, gleicher Simulationszustand)

Fünf Läufe auf dem Endstand: `GFX_ARGS="--gfx-preset=<p>" SCREEN=<b×h> tools/ab_shot.sh <out> <Etappe> --weather=normal
--vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --no-countdown --hour=12
--start-speed=120` (ab_shot.sh ruft Arcade und Modern selbst mit `--graphics=arcade|modern`, eigenem absolutem
`XDG_DATA_HOME` und gleichem Simulationszustand auf). Jeder Lauf: exit 0, 0 Zeilen `SCRIPT ERROR`/`ERROR` in beiden
Logs (gemessen):

| Bild | Stelle | Voreinstellung | Laufzeit | Was im Bild steht – angesehen |
|---|---|---|---|---|
| `ab_kh54_hoch_00/01.jpg` | Kiel–Hamburg km 54,6 / 54,8 | Hoch, 1280×720 | 243 s | Eiche nah mit hellerem Kronendach wie das Sprite, Busch als laubiger Ballen, Birken mit weißem Stamm, Fernbilder ohne graue Flecken |
| `ab_kh54_deck_00/01.jpg` | Kiel–Hamburg km 54,6 / 54,9 (Stelle der Kritik) | Deck, 1280×800 | 156 s | wie Hoch. Die nahe Eiche bleibt ein Haufen Kuppeln wie beim Sprite; die Ränder sind etwas weicher als vorher, einzelne gerade Kanten bleiben (Bild 08) |
| `ab_bm42_hoch_00/01.jpg` | Barcelona–Montpellier km 42,7 | Hoch | 221 s | Palmen mit breiter, hängender Krone und dunklem Stamm; Olive silbergrau ohne Tarnmuster; Zypressen wie das Sprite |
| `ab_lb148_hoch_00/01.jpg` | Lyon–Bern km 149 | Hoch | 222 s | Fichten wie das Sprite. Die Klippe steht hier quer zur Straße (der Props-Bauer würfelt die Drehung) und zeigt von der Schmalseite einen geschlossenen Fels mit Sträuchern auf dem Grat – kein Horn, keine Fetzen; schmaler als das Sprite, bis R2/R7 `face_road` auswerten |
| `ab_hh47_mittel_00.jpg` | Hamburg–Hannover km 47,7 (Heide) | Mittel | 138 s | Heidepolster lila mit Grün wie im Sprite, Birken und Kiefern |

Vorher / nachher im Rennen (Bild 08, gleiche Argumente wie die Kritik): Die Palme ist deutlich näher am Sprite, die
Olive ruhiger. Bei der nahen Eiche auf dem Deck ist der Unterschied klein.

## 6. Gates auf dem Endstand

Alle Gates liefen auf **638debc** (Endstand). Jeder schwere Lauf lief mit `nice -n 19` und einem Arbeiter, immer nur
einer zur selben Zeit. `$BPY` = `/home/user/tools/bpyenv/bin/python`.

| Gate | Befehl | Ausgabe | Ergebnis |
|---|---|---|---|
| Sprite-Geometrie | `$BPY tools/blender/check_sprite_geometry.py --only props --jobs 1` | `86 Sprite-Sets gebaut in 196 s: 86 identisch (davon 0 mit anderer Flächenreihenfolge), 0 nur Fließkomma-Rauschen, 0 verändert, 0 fehlen` · `CHECK sprite_geometry OK` · 0 × „ANDERS“ | grün |
| Cache-Schlüssel | `$BPY tools/blender/export_models.py --check-keys` | `CHECK cache_keys OK      46 Modelle: ein geänderter Lack, Metallwert, Blickwinkel oder eine Markierung im Sprite-Katalog ergibt für genau die betroffenen Modelle einen neuen Schlüssel` | grün |
| Determinismus | erzwungener Export aller 27 AS3-Modelle: `$BPY tools/blender/export_models.py --only=<glob> --force --jobs=1` für `props/tree_*`, `props/bush_*`, `props/cover_*`, `props/heather`, `props/rock_*`, `props/cliff` (350 s), dann `godot --headless --path . -s res://tools/models/bake_models.gd -- --only=<glob>` (je 0 Fehler), `godot --headless --path . --import`, `export_models.py --manifest-only`, `git status --porcelain` | `geschrieben: assets/models/manifest.json (46 Modelle, 182 Sets: 51 mit Modell, 131 Platzhalter)` · `git status`: leer bis auf das unversionierte Messwerkzeug `tools/kritik/` (inzwischen gelöscht) | grün, byte-gleich |
| Prüfer | `python3 tools/blender/validate_models.py --report` | `validate_models: 46 Modelle, 182 Sets (51 mit Modell, 131 Platzhalter)` · `Netze 5.27 MB von 40 MB, Texturen 25.37 MB im Grafikspeicher von 240 MB, Quellen 22.12 MB von 60 MB` · `CHECK models OK`, exit 0 | grün |
| Budget §4.6.9 | Tabelle 4.6 | Bäume ≤ 2 475 / 890 Dreiecke, ≤ 270 Karten, 2 / 2 / 1 Aufrufe; Büsche und Heide ≤ 396 / 118; Felsen 640 / 960; Klippe 5 799 von 6 000 | grün |
| Rennen A/B | `tools/ab_shot.sh` an fünf Stellen (Abschnitt 5) | alle exit 0; 0 Zeilen `SCRIPT ERROR`/`ERROR` in den Arcade- und Modern-Logs | grün |
| Tests (einmal) | `tools/run_tests.sh` | `298 Skripte geprüft, 0 fehlerhaft` … `692 Tests, 2 fehlgeschlagen` · `Tests FEHLGESCHLAGEN (271 s)` | **rot – nur die zwei bekannten Tests von R2** |
| Arcade-Bilder (einmal) | `tools/golden.sh check` | `GOLDEN arcade: 20 von 20 identisch (169 s)`, exit 0 | grün |
| Modell-Check (einzeln) | `godot --headless --path . -s res://tests/race3d/check_models.gd` | `CHECK models OK validate_models.py: 46 Modelle, 182 Sets (51 mit Modell, 131 Platzhalter)` · `CHECK defekte_dateien OK` · `CHECKS OK (0 fehlgeschlagen, 2 s)` | grün |
| Etappen-Check (einzeln) | `godot --headless --path . -s res://tests/race3d/check_modern_stage.gd -- --only=inhalt` | `CHECK inhalt OK Kiel – Hamburg: Straße (704 Dreiecke in 11 Stücken) …` · `CHECKS OK (0 fehlgeschlagen, 2 s)` | grün |

**Die zwei roten Tests** sind dieselben wie bei AS3 (be866d2): `tests/unit/race3d/test_props.gd ::
test_library_resolves_every_prop_set` („Buche: noch eine Vertretung: erwartet 2, ist 1“) und
`:: test_placement_drops_and_lamps` (`SCRIPT ERROR: Invalid access to property or key 's|props/tree_beech|1'`). Der
Test des Props-Bauers (R2) nimmt die Buche als Beispiel eines Sets ohne Modell, seit AS3 hat sie eins. Die Datei gehört
R2, ich habe sie nicht geändert; einen geprüften Vorschlag gibt es in `deliver/AS3/vorschlag_test_props_fuer_R2.diff`.
Der Klangtest, der bei AS3 unter Last rot war, ist diesmal grün. Weil `run_tests.sh` nach einem roten Unit-Test die
Integrationsszenarien und die Modern-Checks (`tests/race3d/check_*.gd`) überspringt, liefen die beiden Checks, die
Modelle laden, einzeln (Zeilen „einzeln“ oben).

Hinweis zum Ablauf: Der erste Hintergrundlauf der Gates wurde bei 30 Minuten vom Zeitlimit der Sitzung beendet, gleich
nach der Skriptprüfung von `run_tests.sh` (nur die Zeile `298 Skripte geprüft, 0 fehlerhaft`). Der Testlauf oben ist
der zweite und letzte; erst danach lief `golden.sh check`, einmal.

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
- Der Stufenwechsel bei 60 m bleibt sichtbar (63–73 % geänderte Pixel bei Laubbäumen) – ohne Überblendung im
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

Kein Befund wurde abgelehnt: jeder ließ sich auf be866d2 nachstellen (Bilder und Messzeilen der Kritik, eigene
Renderings, Code). Abweichungen vom Vorschlag der Kritik oder vom Ziel:

1. **M6 nur teilweise behoben.** lod1 liegt auf dem Rand von lod0; die Helligkeit springt mittags höchstens ±5 %
   (gemessen; abends und nachts siehe Punkt 11). Das Muster im Innern ändert sich aber weiter in 63–73 % der Pixel. Ein lod1 aus Fächern über dem ganzen
   lod0-Rand (gleiches Innen-UV) wurde gebaut und verworfen: Helligkeit −26 %, 15 % weniger Pixel, stachelige Kronen
   (gemessen, angesehen). Die eigentliche Abhilfe ist die Überblendung im Props-Bauer, und der gehört R2/R7 (Renderer).
2. **M5 ohne den Schalter `baked_light`.** Statt eines Kennzeichens, das R2/R7 im Shader auswerten müssten, steckt das
   Relief normiert (Mittel 1) im Albedo des Fernbilds; `billboard.gdshader` bleibt unverändert. Mittags passt das
   (Kontrast −22 … +14 % gegen lod1, gemessen). Abends und nachts zeigt das Fernbild aber weiter das Mittagsrelief
   (Kontrast gegen lod1 +10 … +121 %, gemessen).
3. **M4 mit 15 statt höchstens 12 Kuppeln und Rand (1, 6, 12) statt (1, 8, 16).** So passen Kern, Schürze und
   lod1-Kern ins Budget: 380 / 116 von 400 / 120 Dreiecken (gemessen). Unter 20 m ist der Busch noch leicht
   facettiert (angesehen).
4. **M9 ohne 512²-Laubatlanten** für Olive, Zypresse, Palme und Kiefer. Nach der Atlas-Teilung braucht der ganze Satz
   22,1 von 60 MB (gemessen). Die Olive steht im Rennen bis auf 20 m an der Straße, und dort braucht ihr Laub den
   1024²-Atlas (gefolgert). Das lässt sich nachholen, wenn AS4–AS6 den Platz brauchen.
5. **M3 nicht ganz behoben:** Oben in der Krone von `tree_oak_b` bleiben zwei dünne dunkle Striche (unter 20 m,
   angesehen). Kein Holz liegt außerhalb von 90 % der Kugeln oder 92 % der Krone, und es gibt keine Splitterkuppel.
   `min_exposed` = 4 wurde probiert und zurückgenommen. Die Ursache habe ich nicht gefunden.
6. **M7 Heide:** Die Modellseite ist erledigt (Schürze bis −0,4 m, Kennzeichen `ground_align`). Am 30°-Hang hängt die
   Talseite trotzdem in der Luft, bis der Props-Bauer das Kennzeichen auswertet (R2/R7).
7. **Kennzeichen-Format:** Statt eines neuen Schlüssels `ground: "align" | "sink"` (Vorschlag der Kritik) stehen
   `ground_align`, `ground_sink` und `face_road` in der vorhandenen Liste `tags`. Damit braucht das Manifest keinen
   neuen Schlüssel.
8. **M11 Olive:** Der Stamm im Fernbild bleibt 0,67 m breit (lod1 0,83 m, gemessen). Der Befund ist niedrig und
   wurde nicht angefasst.
9. **M11 Kiefer:** lod1 flimmert in 80 / 150 m etwas mehr als vorher (siehe 4.4), weil der volle Kuppelrand mehr
   dünne Kanten zeigt. Das Arcade-Sprite liegt bei 3,7 / 7,5 %.
10. **Palme:** Kontrast lod1 → Fernbild weiter rund −60 % (gemessen); die dünnen Wedel lösen sich in 256–512 px
    kaum auf. In 40 / 80 / 150 m flimmert die Palme etwas mehr als vorher (Wedel breiter, siehe 4.4).
11. **Rückschritt bei `olive_b`:** Seit ihr lod1 den vollen Kuppelrand trägt (letzte Runde), springt die Helligkeit
    lod0 → lod1 um +5,0 / +6,5 / +8,3 % (Mittag / Abend / Nacht, vorher −1,8 / −0,7 / −1,1 %, gemessen). Den
    Mittagswert (+5,0 %, gerade noch im Rahmen) kannte ich vor den Gates, Abend und Nacht habe ich erst danach
    gemessen. Für eine Korrektur hätten Tests und Arcade-Bilder ein weiteres Mal laufen müssen, und beide waren schon
    gelaufen (höchstens zweimal bzw. einmal). Die Korrektur ist ein Helligkeitsabgleich (`lift`) für lod1 der Olive.

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
