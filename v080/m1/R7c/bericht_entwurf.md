# R7c – Fern-LOD der Bauten und Pflanzen (Welle 5, „R7“; Nachträge A-16, A-19, A-22, Leitentscheide 1–8)

- Zweig `worktree-wf_ba4424b4-294-3`, gesichert als `origin/wip/v080-r7c`; Arbeitsbaum
  `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-3`.
- Basis `9b02f05` (RINT-M2, ff-only), darauf `wip/v080-as5ar2` (`216ac5c`) mit `--no-ff` gemischt (`43a1fcc`):
  Konflikt nur in `tests/golden/modern_slice.{env,md5}` – Stand der Basis behalten (A-18: die Montage erneuert die
  Modern-Goldens); `manifest.json` neu erzeugt (110 Modelle, 183 Sets), `validate_models.py`: `CHECK models OK`.
- **gemessen** = auf dieser VM (Mesa llvmpipe unter Xvfb, Godot 4.7.2, bis zu sechs Agenten auf 4 Kernen);
  **angesehen** = Urteil nach Bildern; **gefolgert** = hier nicht messbar (echte Grafikkarte, Steam Deck, Wirkung auf
  einen Menschen).

## 1. Ergebnis in Kürze

- **Überblenden der Stufen (Leitentscheid 1, A-22):** Bauten und Pflanzen wählen ihre Detailstufe jetzt **je Instanz**
  und blenden über ein Raster-Band über (lod0 ↔ lod1 ↔ Fernbild), statt je 96-m-Stück hart zu springen. Render-Prüfung:
  größte Änderung je 0,5 m am Barockhaus 0,6 % statt 7,1 % (hart), an der Eiche (lod1 → Fernbild) 1,1 % statt 36,6 %,
  keine Löcher (gemessen). In den Clips Paris und Nürnberg bei „Mittel“ ist kein Stufenwechsel zu sehen (Bild für Bild
  angesehen, Spitzen ≤ 5,7 % über den Nachbarbildern, alle Bewegung). lod0-Entfernung je Modell aus `max_dist_m`, bis
  das Asset-Paket sie setzt per Konfiguration: Stadthäuser 35 m, Fachwerk und Paris 30 m bei „Mittel“.
- **Fernlicht (2):** jenseits der Schattenreichweite bleiben Gebäude so hell wie mit Schatten: 60 → 250 m in ±5 % für
  die gemessenen Häuser (Hoch und Mittel; vorher bis +29 %; drei Modelle mit eigenem Wert, nachgemessen); in der Nähe
  unverändert (gleiche Werte bei 60 m).
- **Flimmern (3):** Alphatest aus gröberer Mip, Farb-Bias ab 30 m, kürzeres lod0: Haussmann/Eckhaus/Grachtenhaus B,
  Loire-Haus und Bäume ≤ 2 × Sprite; Fachwerk lod1 bei 100–150 m 2,0–2,25 ×, Südhaus bei 40 m 3 × (Restkanten, nur MSAA).
- **Fenster in der Dämmerung (4):** um 19:30 leuchten so viele Fenster wie in Arcade (angesehen); 22 Uhr unverändert.
- **Fernbilder (5):** Überblenden je Baum, Relief des Sprite-Lichts nachts zurückgenommen (Nachtbilder angesehen).
- **Anbauten (6)** gebaut und mit Test-Manifest geprüft; ganze Fassaden als `baked_cutout` kosten auf llvmpipe das
  1,9- bis 2,4-fache (gemessen). **Tags und Rotorphase (7)** gebaut und geprüft. **Instanzbudget (8):** keine neue
  Instanz-Uniform.
- **Gates (Abschnitt 5):** Import sauber, Skripte 331/0, Tests 808/0 (zweimal), Arcade-Goldens 20 von 20 und 17 von 17, Render-Prüfungen 29 von 29 grün (nach zwei behobenen Funden), Sicht 6/6 und Wege 2/2 mit `--full`, Modern-Goldens erneuert nach Ansicht, @@MCHECK_KURZ@@.
- **Leistung (Abschnitt 6):** ganze Etappe Kiel – Hamburg gleich schnell wie die Basis (Wandzeit 154 / 150 gegen
  153 / 149 s), 12 % weniger Primitive, 59 % weniger im Schatten, Haken der Requisiten +0,1 ms je Bild.
- **Nicht gut / offen:** nachts leuchten an Haussmann, Kontor und Fachwerk deutlich weniger Fenster als in Arcade
  (Fensterauswahl im Modell, F-04); im Lyon-Vorort und in Kurveninnenseiten des Waldes fehlen Häuser und Bäume, die
  Arcade zeigt (schon in der Basis, Korridor-Regel); Fachwerk lod1 flimmert bei 150 m noch 2,25 × Sprite.

## 2. Umsetzung je Leitentscheid

| Leitentscheid | Umsetzung | Dateien |
|---|---|---|
| 1 Überblenden der Stufen, lod0-Entfernung je Modell (A-22) | Stufe **je Instanz** nach dem Abstand des Instanz-Ursprungs zur Hauptkamera, Raster-Überblenden über ±12 % (mind. 4 m, höchst. 25 m) im Shader (`inc/lod_band.gdshaderinc`); jede Stufe hat eigene Materialien (eines je Netz, `ModernMaterials.material(…, netzpfad)`), auf die `props.gd` das Band setzt; das Stück schaltet nur Knoten ab, deren Band keine Instanz erreicht. lod0 = `prop_lod0_m` × `max_dist_m` (model.json) / 60; `graphics.modern.props.lod0_m` ersetzt es je Modell oder Tag (Stadthäuser 35 m, Fachwerk und Paris 30 m bei „Mittel“) | `props.gd`, `prop_library.gd`, `modern_materials.gd`, `model_factory.gd`, `baked/leaves/billboard.gdshader`, `inc/lod_band.gdshaderinc`, Konfiguration |
| 2 Fernlicht ±5 % | jenseits der Schattenreichweite (mit dem Ausblenden der Engine ab 85 %) senkt `far_sun` den gerichteten Anteil auf Modellen, die selbst werfen (Gebäude 0,78, Bäume 0,8, Chalet 0,3, Fachwerk und house_med 0,85, Haussmann 0,72, Südhaus 0,75); `baked` hat dafür ein `light()` mit dem Modell der Engine (Lambert + Schlick-GGX), `vpbr_static` und `leaves` dieselbe Abschwächung | wie oben |
| 3 Flimmern ≤ 2 × Sprite | Alphatest von `baked_cutout` aus einer 2 Stufen gröberen Mip (Schwelle bleibt 0,5, A-22), Farb-Mip-Bias ab 30 m bis 1,25 bei 120 m, kürzeres lod0 (35 / 30 m); Alpha-to-Coverage nicht versucht (nicht als Weg in Compatibility belegt). Die Werte setzt `props.gd` (`PROP_LOOK`) nur auf die Materialien seiner Modelle – die Vorgaben des Shaders lassen Tafeln der Tore, Tankstellen und Grenzen wie vorher (die Render-Prüfung `zieltor` fand das Schachbrett des Zielbanners sonst verwaschen) | `baked.gdshader`, `props.gd`, Konfiguration |
| 4 Fenster in der Dämmerung | leuchtende Pixel ersetzen mit der Nacht die beleuchtete Fassadenfarbe (Arcade: Lichtebene über dem Sprite), volles Licht ab `ce_night` 0,6 (`window_ramp`; Palette 0,65 um 19:30); 22 Uhr unverändert; nicht bei abgeschaltetem Nachtatlas (Pylone); nur auf Requisiten (`PROP_LOOK`) | `baked.gdshader`, `props.gd` |
| 5 Fernbilder, Baum-Überblenden | das Fernbild blendet per Baum über dasselbe Band ein (lod1 → Fernbild bei 200 m ± 24 m, Mittel); `relief_night` 0,75 × Nacht nimmt das Relief des Sprite-Lichts (Richtung Mittelfarbe des Bildes) | `billboard.gdshader`, `prop_library.gd`, `model_factory.gd` |
| 6 Anbauten | `model.json` "attach": [{"prop", "offset", "scale"}] → `PropLibrary.attachments()`, `props.gd` `attach_item()` stellt sie als Instanzen ihrer Sets (eigene Stufen, eigene Auslassungen, links gespiegelt), Liste `attach_list`; Test mit Test-Manifest; GPU-Kosten von Ausschneide-Fassaden gemessen (3.5) | `props.gd`, `prop_library.gd`, `test_props.gd` |
| 7 Tags, Rotorphase | `ground_align` (Neigung zur Geländenormalen ≤ 30°), `ground_sink` (tiefster Punkt eines Kreises der halben Ausdehnung), `face_road` (±20°); Phase je Instanz in den Custom-Daten (a = 1 + Phase): Rotoren (vpbr_static, Einschub in `static_code()`) und Wiegen der Bäume (leaves) springen nicht mehr beim Verschieben des Ursprungs | `props.gd`, `modern_materials.gd`, `leaves.gdshader` |
| 8 Instanzbudget (A-19) | keine Instanz-Uniform neu; alles über Material-Uniforms (je Netz) und MultiMesh-Custom-Daten | – |
| Wächter | `quality_lowered()` setzt Bänder auf Materialien und Knoten neu | `props.gd` |

## 3. Messungen (alle gemessen auf dieser VM, llvmpipe unter Xvfb; Werkzeuge: Kopien der Prüfszenen von AS5aR2 in `m1/R7c/kt`, `k5.sh`)

### 3.1 Fernlicht (Leitentscheid 2) – `k6_scene --mode=lodcol`, 12 Uhr, Modell 20 m neben der Straße

Mittlere Helligkeit (Luma) des Modells, Abweichung gegen das Nahbild (Hoch: 60 m, Mittel: 50/60 m; lod1, dieselbe
Szene wie AS5aR2 K2). Vorher = ohne Fernlicht (identisch mit den Werten von AS5aR2: Haussmann 134 → 147, Chalet
75 → 96, Lauben 105 → 110, Südhaus 116 → 127, Maashaus 107 → 111 – der neue `light()` des `baked`-Shaders gibt bei 60 m
dieselben Werte wie das eingebaute Licht der Engine).

| Modell | vorher 250 m (Hoch) | far_sun 0,75 Hoch 100 / 140 / 200 / 250 m | Mittel 100 / 140 / 200 / 250 m |
|---|---|---|---|
| Haussmann | +10 % | +2,2 / +2,4 / +3,6 / +4,1 % | +0,5 / +3,9 / +4,3 / +4,3 % |
| Pariser Eckhaus | – | +1,3 / +1,4 / +0,3 / −0,1 % | −0,1 / +1,3 / +1,3 / +0,4 % |
| Lauben | +5 % | −1,5 / −2,9 / −1,9 / −2,2 % | −2,5 / −1,2 / −1,7 / −2,0 % |
| Südhaus | +10 % | +1,6 / +1,1 / +3,4 / +3,0 % | −0,5 / +4,1 / +2,8 / +2,6 % |
| Maashaus | +4 % | +0,6 / +0,8 / −4,8 / −4,1 % | +0,6 / −3,4 / −3,4 / −3,1 % |
| Lütticher Reihe | – | −0,3 / −0,3 / −5,8 / −5,3 % | −0,8 / −4,7 / −5,0 / −4,7 % |
| Grachtenhaus | – | −0,7 / −0,8 / −5,7 / −5,8 % | −0,7 / −4,6 / −4,2 / −5,0 % |
| niederl. Reihe | – | +1,6 / +1,9 / −2,2 / −2,6 % | +0,8 / −2,1 / −2,1 / −2,6 % |
| Gründerzeit | – | −0,5 / −0,9 / −3,8 / −3,7 % | −1,3 / −2,8 / −3,2 / −3,3 % |
| Kontor | – | +3,4 / +4,2 / +0,6 / +1,0 % | +1,1 / +1,0 / +1,3 / +1,1 % |
| Giebelhaus (Hanse) | – | +0,6 / +1,3 / −3,2 / −3,0 % | +0,5 / −2,9 / −2,2 / −2,4 % |
| Barockhaus | – | −0,4 / −0,6 / −4,3 / −4,1 % | −1,2 / −3,1 / −3,8 / −3,6 % |
| Lyoner Haus | – | +0,3 / −0,3 / −2,0 / −2,0 % | −0,5 / −1,5 / −1,5 / −1,5 % |
| house_med | – | +0,2 / −0,9 / −4,8 / −5,4 % | −1,4 / −2,2 / −5,0 / −5,0 % |

Mit 0,75 lagen drei Modelle bei Hoch knapp unter −5 % (−5,3 … −5,8 %) und Haussmann bei +4,1 %; ausgeliefert ist
deshalb 0,78. Nachmessung mit 0,78 (lod0 bis 250 m, das strengere Bild): Lütticher Reihe −3,5 %, Grachtenhaus −0,4 %,
Maashaus −2,7 % bei 200 m – aber Haussmann +5,9 / +6,6 %, house_med −5,4 / −5,1 % und Südhaus +5,5 % (140 m,
Mittel) außerhalb. Diese drei haben eigene Werte (Haussmann 0,72, Südhaus 0,75, house_med 0,85) und sind damit
nachgemessen (Abweichung gegen 60 m bei 100 / 140 / 200 / 250 m):

| Modell (eigener Wert) | Hoch | Mittel |
|---|---|---|
| Haussmann (0,72) | +2,5 / +2,8 / +3,2 / +2,9 % | +0,5 / +3,8 / +3,7 / +2,8 % |
| Südhaus (0,75) | +1,6 / +1,3 / +3,8 / +3,6 % | −0,5 / +4,8 / +3,2 / +3,2 % |
| house_med (0,85) | +0,2 / −0,5 / −1,2 / −2,0 % | −1,4 / +0,5 / −1,5 / −1,8 % |

Schlussmessung der übrigen Häuser mit ihren ausgelieferten Werten (lod0 bis 250 m; Kontor, Chalet und Fachwerk auch
in lod1, der Stufe, die das Spiel jenseits von 35 m zeigt):

| Modell (Wert) | Hoch 100 / 140 / 200 / 250 m | Mittel 100 / 140 / 200 / 250 m |
|---|---|---|
| niederl. Reihe (0,78) | +2,1 / +2,8 / +0,7 / −0,8 % | +1,0 / −0,1 / +0,6 / −0,9 % |
| Lyoner Haus (0,78) | +0,6 / −0,2 / −0,7 / −0,8 % | −0,4 / −0,2 / −0,1 / −0,2 % |
| Gründerzeit (0,78) | −0,1 / −0,6 / −2,2 / −2,5 % | −1,2 / −1,3 / −1,8 / −2,2 % |
| Barockhaus (0,78) | −0,4 / −0,6 / −2,9 / −3,4 % | −1,2 / −1,9 / −2,4 / −2,9 % |
| Giebelhaus (0,78) | +1,1 / +2,0 / −1,7 / −0,9 % | +0,7 / −1,1 / −0,6 / −0,2 % |
| Pariser Eckhaus (0,78) | +1,5 / +1,6 / +1,6 / +1,1 % | −0,1 / +2,8 / +2,4 / +1,5 % |
| Lauben (0,78) | −1,2 / −2,6 / −0,6 / −0,9 % | −2,3 / −0,1 / −0,4 / −0,8 % |
| Kontor (0,78) **lod0** | **+7,8 / +11,2 / +12,1 / +13,3 %** | +4,0 / **+11,6 / +13,1 / +13,6 %** |
| Kontor (0,78) lod1 | +3,4 / +4,2 / +1,7 / +1,9 % | +1,1 / +2,1 / +2,5 / +2,3 % |
| Fachwerkzeile (0,85) lod0 / lod1 | −0,1 / −0,9 / −2,3 / −2,6 – +1,4 / +1,5 / +1,1 / +1,0 % | −1,7 / −1,1 / −1,9 / −2,3 – +0,0 / +0,9 / +1,7 / +1,4 % |
| Fachwerkzeile B (0,85) lod0 / lod1 | −1,9 / −3,4 / −4,1 / −2,7 – −1,7 / −2,8 / −1,9 / −2,0 % | −3,4 / −1,3 / −3,7 / −2,4 – −2,8 / −1,0 / −1,6 / −1,6 % |
| Chalet lod1 mit 0,35 | +2,4 / +0,8 / **+6,3** / +4,1 % | −0,5 / **+5,6** / +3,3 / +3,7 % |
| Chalet lod1 mit **0,30** (ausgeliefert) | +2,4 / +0,8 / +3,6 / +1,3 % | −0,5 / +2,8 / +0,7 / +0,9 % |

Damit liegen alle 17 gemessenen Häuser mit ihren ausgelieferten Werten bei 100–250 m in ±5 % des Bildes bei 60 m
(gemessen; Haussmann, Südhaus, house_med und die drei belgisch-niederländischen mit 0,78 nur in lod0). Ausnahme: das
Kontor in lod0 wird fern bis 13 % heller (seine tiefen Laibungen werfen in lod0 viel Eigenschatten) – im Spiel endet
lod0 der Stadthäuser aber bei 35 m („Mittel“) bzw. 70 m („Hoch“), jenseits davon steht lod1, und das liegt in ±5 %.

Suche der Einzelwerte: Chalet vorher +29 % bei 250 m (Hoch), 0,3 → +1,1 %, 0,45 → +8,8 %; 0,35 lag bei 200 m über
5 % (Tabelle), ausgeliefert 0,3. Fachwerk 0,85 (0,75 → −4,5 / −5,7 % bei Mittel). Bäume (Mittel, 0,75): Eiche
+2,0 / +2,7 % bei 140 / 250 m (vorher +4,4 %), Kiefer lod1 +3,9 % bei 140 m; ausgeliefert 0,8.

### 3.2 Flimmern (Leitentscheid 3) – `my_scene --mode=sparkcam`, Mittel, 12 Uhr, Anteil kippender Pixel je Viertelpixel-Schritt

Vorher = Stand der Basis (Alphatest bei Mip 0, kein Farb-Bias); Sprite = die Vertretung desselben Sets im selben Licht.

| Modell | Stufe | vorher 40 / 60 / 100 / 150 m | nachher | Sprite |
|---|---|---|---|---|
| Haussmann | lod0 | 0,9 / 1,1 / 1,2 / 0,9 % | lod0 endet bei 30 m (Mittel) | 0,0 / 0,2 / 0,3 / 0,4 % |
| Haussmann | lod1 | 0,2 / 0,2 / 0,3 / 0,5 % | 0,1 / 0,1 / 0,2 / 0,3 % | |
| Pariser Eckhaus | lod0 | 1,1 / 1,1 / 1,2 / 1,0 % | lod0 endet bei 30 m | 0,1 / 0,2 / 0,2 / 0,3 % |
| Pariser Eckhaus | lod1 | 0,1 / 0,2 / 0,2 / 0,4 % | (wie vorher, kein Ausschnitt in lod1) | |
| Fachwerkzeile | lod0 | 1,1 / 1,3 / 1,9 / 3,1 % | lod0 endet bei 30 m | 0,1 / 0,1 / 0,2 / 0,4 % |
| Fachwerkzeile | lod1 | 0,2 / 0,2 / 0,6 / 1,1 % | 0,2 / 0,2 / 0,4 / 0,9 % | |
| Grachtenhäuser B | lod1 | – | 0,2 / 0,3 / 0,3 / 0,5 % | 0,1 / 0,2 / 0,2 / 0,4 % (AS5aR2) |
| Kontor | lod1 | – | 0,2 / 0,2 / 0,5 / 0,9 % | – |
| Südhaus (Gartenbaum-Karten) | lod1 | 0,8 / 0,9 / 1,0 / 1,5 % | 0,6 / 0,5 / 0,7 / 1,1 % | 0,2 / 0,3 / 0,4 / 0,6 % |
| Loire-Haus (Gartenbaum) | lod1 | 0,4 / 0,6 / 1,3 / 1,6 % | 0,3 / 0,4 / 1,0 / 1,1 % | 0,2 / 0,4 / 0,6 / 0,9 % |
| Eiche | lod0 / lod1 | 0,7 / 1,1 / 1,8 / 2,9 – 0,7 / 1,2 / 2,1 / 3,3 % | unverändert | 0,6 / 0,8 / 1,3 / 2,0 % |
| Buche | lod0 / lod1 | 0,6 / 0,9 / 1,7 / 2,2 – 0,7 / 1,1 / 1,9 / 2,5 % | unverändert | 0,5 / 0,8 / 1,3 / 1,9 % |
| Kiefer | lod0 / lod1 | 2,2 / 4,3 / 8,7 / 12,1 – 2,2 / 4,1 / 8,4 / 11,9 % | unverändert | 2,0 / 3,0 / 4,6 / 7,0 % |

lod0 anderer Stadthäuser bei 40 / 60 m (mit den neuen Bias-Werten; daher das kürzere lod0 von 35 m für alle Häuser
mit dem Tag `city`): Gründerzeit 0,4 / 0,3 %, Barock 0,5 / 0,4 %, Kontor 0,3 / 0,2 %, Speicher 0,4 / 0,3 %, Lyoner Haus
0,3 / 0,2 %, Lütticher Reihe 0,3 / 0,3 %, Grachtenhaus 0,6 / 0,7 %, Chalet 0,4 / 0,7 %, Fachwerkzeile B 1,4 / 1,1 % –
Sprites 0,0 … 0,2 %.

Urteil gegen „höchstens 2 × Sprite“ (40–150 m, in der Stufe, die bei „Mittel“ dort steht): erfüllt für Haussmann,
Eckhaus, Grachtenhäuser B, Loire-Haus und die Bäume (Eiche ≤ 1,65 ×, Buche ≤ 1,4 ×, Kiefer ≤ 1,8 ×); knapp darüber
Fachwerkzeile lod1 bei 100 / 150 m (2,0 / 2,25 ×) und Südhaus bei 40 m (3 ×, 0,6 gegen 0,2 %) und 150 m (1,8 ×);
beides Geometrie- und Kartenkanten, die nur Kantenglättung (MSAA „Hoch“ 4 ×, TAA gibt es nicht) weiter dämpft.

### 3.3 Überblenden der Stufen (Leitentscheid 1)

**Render-Prüfung `tests/race3d/render/check_lod_band.gd`** (neu, läuft mit `tools/run_render_checks.sh modern`): ein
Modell steht still vor der stillstehenden Kamera, das Ende von lod0 wird in 0,5-m-Schritten durch seinen Abstand
geschoben (wie Heranfahren, ohne die Bewegung des Bildes); gemessen wird die größte Änderung zwischen zwei Schritten
(Anteil der Pixel des Modells, die sich um mehr als 40 Stufen ändern), hart (Bandbreite 0,01 m) gegen das Band des
Requisiten-Bausteins, und die Deckung im Band (Löcher).

| Fall | hart | mit Band | Deckung im Band |
|---|---|---|---|
| Barockhaus lod0 → lod1 bei 34 m, erster Lauf | 7,1 % | **9,3 %** (FEHLER) | −0,0 % |
| Barockhaus, nach der Korrektur des Schattendurchgangs (`6eaa7e0`) | 7,1 % | **0,6 %** (OK) | −0,0 % |
| Eiche lod1 → Fernbild bei 150 m | 36,6 % | 1,1 % | −0,0 % |

Der erste Lauf deckte einen Fehler auf: im Schattendurchgang entschied die Bandmitte, und die flache Hülle von lod1
beschattete die zurückliegenden Fenster von lod0, solange beide sich die Pixel teilten (Bild
`lod_mitte_vorher.jpg`: Fenster dunkel gesprenkelt). Jetzt wirft die feinere Stufe durch das ganze Band.

**Clips bei „Mittel“** (20 s, 30 Bilder/s, Arcade | Modern, `tools/ab_clip.sh`; Bild für Bild ausgewertet mit
`py/clipframes.py`: Anteil geänderter Pixel je Bild im oberen Bildteil, Spitzen gegen den Median der ±5 Nachbarbilder):

| Clip | Bilder | Änderung je Bild Median / p95 | größte Spitze über den Nachbarn (ohne Startbild) | angesehen |
|---|---|---|---|---|
| Paris-Einfahrt (Lüttich – Paris km 386,8 → 390, bis 147 km/h) | 645 | 9,1 / 24,0 % | +5,7 % (Bild 189 → 190: Baumkrone dicht vor der Kamera) | kein Stufensprung zu sehen |
| Nürnberg-Altstadt mit Fachwerk (Würzburg – Nürnberg km 101,6 → 104,5, bis 122 km/h), erste Aufnahme | 645 | 15,4 / 25,8 % | +2,6 % | kein Stufensprung zu sehen |
| dieselbe Fahrt auf dem Endstand `138c90f` (nach der Korrektur des Schattendurchgangs; ausgeliefert) | 645 | 15,4 / 25,8 % | +2,5 % (Bild 172 → 173: Bewegung) | kein Stufensprung zu sehen |

Zum Vergleich der harte Wechsel der Basis: 8–32 % der Pixel *eines Hauses* in einem Bild (AS5aR1/AS5aR2, im Bild
eines ganzen Hauses gemessen); in den Clips gibt es keine Spitze dieser Art mehr. Die Streifen der größten Spitzen
(`clip_*_spitze.jpg`) zeigen Bewegung, keinen Wechsel. Den Paris-Clip habe ich vor der Korrektur des Schattendurchgangs (`6eaa7e0`) aufgenommen und nicht wiederholt; einen
Clip der Basis an derselben Stelle habe ich aus Zeitgründen nicht aufgenommen.

### 3.4 Fenster in der Dämmerung (Leitentscheid 4)

Hamburg km 88,6 (Kontor, Giebelzeile), Mittel: um 19:30 leuchten in Modern jetzt etwa so viele Fenster wie in Arcade
(angesehen, `daemmerung_hamburg_1930.jpg`: Arcade | Basis | R7c); in der Basis etwa die Hälfte. Die Zählung warmer Pixel
taugt um 19:00 nicht (die tiefe Sonne färbt die Backsteinfassaden selbst warm). Um 22 Uhr unverändert gegenüber der Basis
(`ce_night` = 1): in Hamburg leuchten rechts weniger Fenster als in Arcade – das ist die Auswahl der Fenster im Modell
(FIX-RINT F-04, Asset-Pipeline), nicht das Gesetz über die Stunde.

### 3.5 GPU-Kosten ganzer Fassaden als `baked_cutout` (Leitentscheid 6, gemessen auf llvmpipe)

24 Instanzen von lod0 in einem Bild (`tools/r7c_tmp/cutout_cost.gd`, nicht eingecheckt), Bildzeit je Bild, zwei Läufe:
Haussmann mit der ganzen Fassade als `baked_cutout` 846 / 878 ms, dieselbe Fläche als `baked` (kein Alphatest,
Rückseiten weg) 480 / 402 ms; Südhaus 681 / 670 gegen 286 / 274 ms. Auf llvmpipe kostet der Alphatest über der ganzen
Fassade also das 1,9- bis 2,4-fache (ohne frühen Tiefentest, beide Seiten); auf einer echten Grafikkarte kleiner,
aber in dieselbe Richtung (gefolgert). Das stützt die dritte Fläche je Stadthaus (opake Fassade `baked`, nur Geländer
und Laub als `baked_cutout`), sobald ein Modell-Paket sie baut.

## 4. Bilder Arcade | Modern (angesehen)

Alle A/B-Bilder mit `tools/ab_shot.sh` (gleicher Simulationsstand, Seed 11, Autopilot, Start mit 50 km/h, Bild 2 s nach
dem Start), Ordner `m1/R7c/shots/city/` (20 Läufe, alle Exit 0, 0 Fehlerzeilen), Auswahl in `deliver/R7c/`.

| Ort | Hoch 12 Uhr | Mittel 19:30 | Hoch 22 Uhr |
|---|---|---|---|
| Hamburg (Kiel – Hamburg km 88,6) | besser: Backsteinfassaden mit Tiefe, Gehweg, Schatten | gleich bis besser: Fenster leuchten wie in Arcade (vorher weniger) | schlechter in einem Punkt: rechts leuchten weniger Fenster als in Arcade (Fensterauswahl im Modell, F-04) |
| Nürnberg (Würzburg – Nürnberg km 102,4) | besser: Fachwerk mit Tiefe, Stadtmauer, Licht | gleich bis besser: Fenster des Bürgerhauses leuchten | schlechter in einem Punkt: das Fachwerk links bleibt dunkler als in Arcade (Fensterauswahl, F-04) |
| Paris (Lüttich – Paris km 387,9, Brücke) | besser: Brückengeländer, Kaimauern, Wasser; Haussmann bei 120 m nicht blass | besser: Läden warm, Fenster wie Arcade | **schlechter**: die Obergeschosse des Haussmann-Hauses bleiben dunkel, Arcade zeigt viele helle Fenster; Läden und Laternen besser (F-04, Nachtatlas der Modelle) |
| Amsterdam (Bremen – Amsterdam km 357,7) | gleich bis besser: Grachtenhäuser fein; Hausboote | gleich bis besser: Hausboote und Giebel beleuchtet | gleich |
| Bern (Lyon – Bern km 302,7) | besser: Lauben, Blumen, Gehweg | besser: ferne Lauben mit Licht | besser: Lauben beleuchtet, ruhige Fenster |
| Lyon-Vorort (Montpellier – Lyon km 286) | **schlechter**: Arcade zeigt rechts nah Häuser mit Gartenbäumen und Mauern, Modern dort freies Feld – schon in der Basis so (`basis_lyon_vorort_hoch_12.jpg`); vermutlich der Kurvenkorridor (F7, R7a) | – | – |
| Wald (Dortmund – Frankfurt km 48–50) | **schlechter** in der Menge: einzelne Fichten und Laubbäume so gut wie Arcade, aber rechts der Straße stehen deutlich weniger Bäume (Arcade: eine Reihe Fichten bis 60 m) – schon in der Basis (`basis_wald_mittel_12.jpg`), Korridor/Bestückung, nicht die Stufen | – | Mittel 22 Uhr: gleich dunkel, Fernbilder ohne helles Relief |

Basis gegen R7c (gleiche Stelle, `basis_*.jpg`): in der Nähe gleich (der neue `light()` ändert dort nichts); ferne
Fassaden über der Schattenreichweite etwas dunkler und satter (das Ziel), Stadthäuser zwischen 35 und 60 m jetzt in
lod1 (kaum sichtbar: lod1 trägt dieselben Atlanten).

Urteil: In den Städten ist Modern bei Tag klar besser als Arcade (Tiefe, Gehwege, Schatten, Details), in der
Dämmerung mindestens gleich, nachts gemischt: Läden, Laternen und Lauben besser, aber an Haussmann (Paris), Kontor
(Hamburg) und Fachwerk (Nürnberg) leuchten deutlich weniger Fenster als in Arcade – die Auswahl der Nachtfenster im
Modell (FIX-RINT F-04, Asset-Pipeline), nicht das Gesetz über die Stunde. Nicht besser: der Lyon-Vorort und Kurveninnenseiten im Wald, wo Modern Häuser und Bäume weglässt, die Arcade
zeigt (Korridor-Regel, nicht dieses Paket).

## 5. Gates (Befehle und Ausgaben; Logs in `m1/R7c/gates/`)

Alle Läufe mit absolutem `XDG_DATA_HOME` unter `m1/R7c/`, `nice -n 10`, Speicherwächter.

| Gate | Befehl | Stand | Ergebnis |
|---|---|---|---|
| Import | `godot --headless --path . --import` | `138c90f` | Exit 0, 0 Zeilen mit error/Fehler |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | `138c90f` | Exit 0 – `331 Skripte geprüft, 0 fehlerhaft` |
| Tests (1. voller Lauf) | `tools/run_tests.sh` | `965b8a9` | Exit 0 – 808 Tests, 0 fehlgeschlagen – 150 CHECK OK, 0 CHECK FEHLER (968 s) |
| Tests (2. voller Lauf) | `tools/run_tests.sh` | `138c90f` | Exit 0 – `808 Tests, 0 fehlgeschlagen` – 150 CHECK OK, 0 CHECK FEHLER (911 s); auf `bd1803b` (nur der Chalet-Wert und die Golden-Liste neu) noch einmal `tools/run_tests.sh test_props`: 18 Tests, 0 fehlgeschlagen |
| Arcade-Goldens | `tools/golden.sh check` | `965b8a9` | `GOLDEN arcade: 20 von 20 identisch`, `GOLDEN arcade-ui: 17 von 17 identisch` (einmal, wie verlangt; danach nur Modern-Dateien geändert: `baked.gdshader`, `props.gd`, Tests, Doku) |
| Modern-Goldens vorher | `KEEP=… tools/golden.sh modern-check` | `965b8a9` | `GOLDEN modern: 0 von 6 identisch` (erwartet), `GOLDEN modern-gles: … OK max. Abweichung 2/255, PSNR 73.2 dB` |
| Modern-Goldens neu | `KEEP=… tools/golden.sh modern-make` | `138c90f` | Exit 0 – `6 Hashes in tests/golden/modern_slice.md5`, Bilder behalten und angesehen (unten); committet in `bd1803b` |
| Modern-Goldens danach | `tools/golden.sh modern-check` | `bd1803b` | @@MCHECK_RESULT@@ |
| Render-Prüfungen | `tools/run_render_checks.sh all` | `138c90f` | Exit 0 – 29 Dateien OK, 0 rot (`RENDER-CHECK-DATEI … OK` für alle; keine SHADER/SCRIPT ERROR) |
| Sicht | `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` | `138c90f` | Exit 0 – 6 CHECK OK, 0 FEHLER (F1, F1 Spuren, F2, F3, F7, Modell) |
| Wege | `godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full` | `138c90f` | Exit 0 – 2 CHECK OK (Abstand ≥ 250 m, Schleifen) |
| Etappe mit Autopilot | `stage.sh` (Abschnitt 6) | `138c90f` / Basis | 4 Läufe Exit 0, 0 Fehlerzeilen, gleich schnell |
| Stufenband | `check_lod_band.gd` (in den Render-Prüfungen) | `138c90f` | Barockhaus 0,6 % gegen hart 7,1 %, Eiche 1,1 % gegen 36,6 %, keine Löcher |
| Instanzbudget (A-19) | `check_instance_budget*.gd` (in den Render-Prüfungen) | `138c90f` | OK – ganze Szene höchstens 141 / 171 / 216 Instanzen mit Instanz-Uniforms (Kiel – Hamburg / Stadt / Wald, Grenze 230), wie in der Basis |

Zwischenstand, der zur letzten Änderung führte: der erste Lauf der Render-Prüfungen (auf `965b8a9`) war in zwei
Dateien rot – `check_structures` (`zieltor`: das Schachbrett des Zielbanners verwaschen, weiß 3 % statt 6 %, durch den
Farb-Bias, der auch die Tafeln traf) und `check_props_render` (die Spiegelprobe suchte das Chalet als Sprite, das seit
AS5a2 ein Modell ist). Beides behoben in `08630e4` und einzeln nachgeprüft (`zieltor` weiß 6 %, `props_spiegel` OK),
dann der ganze Lauf auf dem Endstand.

**Modern-Goldens angesehen** (`modern_goldens_basis_r7c_differenz.jpg`: Basis | R7c | Differenz × 4): gegen die Liste der Basis (RINT-M2, dieselben MD5) sind 0,6–3,8 % der Pixel geändert, die mittlere Helligkeit ist gleich (108,1 → 108,0; 32,2 → 32,3 nachts). Geändert: die Rotoren der Windräder (Phase je Instanz statt aus der Weltlage), Bäume (Wiegen je Instanz, Stufe je Baum), in S4/S5 die Hamburger Häuser (Stufe je Instanz, Fernlicht, Farb-Bias ab 30 m; dazu die Modelle von AS5aR2, die die Basis-Liste noch nicht kannte). Starttor, Zielbanner, Schilder und Tafeln gleich. Gewollt – erneuert mit `modern-make`. Zwischen `965b8a9` und dem Endstand ändert sich nur S4 in 0,03 % der Pixel (Tafeln wieder ohne Farb-Bias).

## 6. Leistung – ganze Etappe mit Autopilot, R7c gegen die Basis (gemessen)

Kiel – Hamburg, „Mittel“, 12 Uhr, Seed 11, Limousine, Zeitraffer 40, `tests/race/run_stage.gd` unter Xvfb
(`m1/R7c/stage.sh`; die Basis-Läufe mit meinen Dateien aus `43a1fcc`, sonst derselbe Stand). Zwei Runden abwechselnd
R7c / Basis (ein erster Lauf lief neben meiner eigenen Render-Nachprüfung und ist verworfen: 254 gegen 159 s).
Neben mir lief auf der VM ein Prüfjob eines anderen Pakets (4 Kerne).

| Wert (perf_stats) | R7c Runde 1 / 2 | Basis Runde 1 / 2 |
|---|---|---|
| Wandzeit der Etappe | 154 / 150 s | 153 / 149 s |
| Bildzeit Median / p95 (Zeitraffer 40, viele Physikschritte je Bild) | 541 / 812 – 544 / 786 ms | 549 / 779 – 532 / 790 ms |
| `render_ms` Mittel / Max | 3,81 / 10,5 – 3,83 / 9,7 ms | 3,59 / 9,6 – 3,73 / 13,0 ms |
| Stück bauen (Worker) Mittel / Max | 4,9 / 17,6 – 5,1 / 17,2 ms | 5,2 / 21,0 – 5,2 / 17,8 ms |
| Stück einhängen Max (Hauptfaden) | 1,77 – 1,71 ms | 1,88 – 1,60 ms |
| Haken `props` je Bild Mittel / Max (Hauptfaden) | 0,20 / 1,5 – 0,20 / 1,4 ms | 0,09 / 0,5 – 0,10 / 2,9 ms |
| `collect` der Requisiten Max | 0,04 ms | 0,04 ms |
| Zeichenaufrufe (letztes Bild) | 157 | 154 |
| Primitive / davon Schatten (letztes Bild) | 158 664 / 28 677 | 180 015 / 69 505 |
| Instanzen mit Instanz-Uniforms (Szene / Fahrzeuge Spitze) | 56 / 128 | 56 / 128 |

Urteil (gemessen): gleich schnell. Der Haken der Requisiten kostet je Bild 0,1 ms mehr (Abstand jedes Stufenknotens
zur Kamera, `_apply_lod`), weit unter dem Hauptfaden-Budget von 2 ms (A-18). Weniger Primitive, vor allem im Schatten
(−59 %); die Ursache habe ich nicht einzeln gemessen – gefolgert: ein Stück blendet jeden Stufenknoten aus, dessen
Band keine seiner Instanzen erreicht (euklidische Spanne der Instanz-Ursprünge), und lod0 endet bei den Stadthäusern
schon bei 35 m. Drei
Zeichenaufrufe mehr (Stufen im Übergang zeichnen beide). Die Zahlen von llvmpipe sagen über eine echte Grafikkarte
nur die Richtung (gefolgert).

## 7. Abweichungen und Vertragsfragen

- **lod0-Entfernungen in der Konfiguration statt in `model.json`** (A-22 sagt „max_dist_m in model.json“): die Mechanik
  liest `max_dist_m` aus `model.json` (heute überall der Exporter-Standard 60), die gemessenen Werte (Stadthäuser 35 m,
  Fachwerk und Paris 30 m bei „Mittel“) stehen bis zur nächsten Neuausgabe der Modelle in
  `graphics.modern.props.lod0_m` (Datei des Renderers). `model.json` gehört den Asset-Paketen; eine Handänderung
  dort würde beim nächsten Export überschrieben (`cities3d.py` setzt `H.LOD0_M` für alle Häuser).
- **Instanzabstand statt Wegabstand**: die Stufe hängt am geraden Abstand Instanz – Kamera (der Shader kennt keinen
  Weg); bisher galt der Wegabstand des Stücks. In Kurven ist der gerade Abstand kürzer, die Stufe also eher feiner.
- **`vpbr_static` per Texteinschub**: Band, Fernlicht und Rotorphase stehen in `ModernMaterials.STATIC_INJECT`
  (eigene Datei), nicht in `vpbr.gdshader` (nicht in meiner Liste, FIX-RINT ändert ihn vielleicht); ein Test prüft
  jeden Einschub. Sauberer wäre es, sie in `vpbr.gdshader` zu schreiben (notes_for_next).
- **Kein `environment_rig.gd`**: das Fernlicht kommt ohne die angebotene Ausnahme aus (Material-Uniforms je Netz,
  gesetzt von `props.gd` aus `levels.shadow_distance_m`). Folge: Modelle, die andere Bausteine zeichnen (Tankstelle,
  Grenze, Brückenteile), bekommen kein Fernlicht.
- **A-18 / Brief**: der Vertrag sagt, Pakete erneuern `tests/golden/modern_slice.*` nicht; der Brief verlangt
  `modern-make` nach Ansicht. Ich bin dem Brief gefolgt (Abschnitt 5).
- **Überblenden über den Weg statt über die Zeit** (A-16: „0,3–0,5 s wie `xfade` der Fahrzeuge“): eine Blende in der
  Zeit bräuchte je Instanz einen Zustand (Instanz-Uniforms sind nach A-19 tabu, MultiMesh-Daten je Bild neu zu
  schreiben wäre teuer). Das Band ist ±12 % der Stufengrenze (mind. 4, höchst. 25 m): bei 100 km/h dauert der Wechsel
  eines Hauses bei 35 m 0,3 s, der eines Baums bei 60 m 0,5 s, lod1 → Fernbild bei 200 m 1,7 s; bei 50 km/h doppelt so
  lange.
- **Bilder**: je Stadt drei der sechs Kombinationen (Hoch 12 Uhr, Mittel 19:30, Hoch 22 Uhr), dazu Nürnberg und Paris
  Mittel 12 Uhr und die Dämmerung in Hamburg (Mittel 19:00 / 19:30 / 22:00) – nicht jede Stadt in jeder Stufe zu jeder
  Stunde (Rechenzeit; die Stufe verschiebt die Entfernungen, nicht das Licht).
- **Flimmern ≤ 2 × Sprite** nicht überall erreicht: Fachwerkzeile lod1 bei 100 / 150 m 2,0 / 2,25 ×, Südhaus bei 40 m
  3 × (Abschnitt 3.2).
- **Arcade-Goldens** einmal auf `965b8a9` (wie verlangt nur einmal); danach habe ich nur Modern-Dateien geändert
  (`baked.gdshader`, `props.gd`, Tests, Doku).

## 8. Für die nächsten Pakete

- Asset-Paket: `H.LOD0_M` in `cities3d.py` je Stil (Stadthäuser 35 m, Fachwerk und Paris 30 m bei „Mittel“ ≙
  `max_dist_m` 35 / 30) beim nächsten Export – dann `graphics.modern.props.lod0_m` leeren.
- Besitzer von `vpbr.gdshader`: `ModernMaterials.STATIC_INJECT` (Band, Fernlicht, Rotorphase) in den Shader selbst
  übernehmen; `test_static_materials_per_mesh_and_injection` bewacht jeden Einschub bis dahin.
- Nachtfenster (F-04, Asset): Haussmann, Kontor und Fachwerk zeigen um 22 Uhr deutlich weniger leuchtende Fenster als
  Arcade – Auswahl im Nachtatlas, nicht im Shader (`window_cover`/`window_ramp` regeln nur die Dämmerung).
- R7a / Korridor: Lyon-Vorort (Montpellier – Lyon km 286) und Kurveninnenseiten im Wald zeigen Häuser/Bäume, die
  Modern weglässt (schon in der Basis); prüfen, ob die Hülle von A-17 dort zu breit ist.
- Stadthäuser: eine dritte Fläche je Haus (opake Fassade `baked`, nur Geländer und Laub `baked_cutout`) – ganze
  Fassaden als Ausschnitt kosten auf llvmpipe das 1,9- bis 2,4-fache.
- Fachwerkzeile lod1 flimmert bei 100–150 m noch 2,0–2,25 × Sprite; Wege: dickere Balken in lod1 oder Fernbild früher.
- Zusammenbau (Probe mit `git merge-tree` gegen den heutigen Stand der Sicherungszweige): mit `wip/v080-r7a` und
  `wip/v080-r7b` ohne Konflikt; mit `wip/v080-fix-rint` ein Konflikt in `tests/unit/race3d/test_props.gd`
  (`modern_materials.gd` mischt sich selbst).
- Fernlicht nur auf den Modellen von `props.gd`; Tankstelle, Grenze und Brückenteile bekommen es, wenn ihre Bausteine
  `shadow_far`/`far_sun` auf ihre Materialien setzen (Uniforms sind in `baked` schon da).
- Neue Uniforms in `baked.gdshader` (`albedo_bias`, `cutout_bias`, `window_ramp`, `window_cover`) haben neutrale
  Vorgaben; wer sie für andere Modelle will, setzt sie wie `props.gd` (`PROP_LOOK`).
- Der Paris-Clip stammt von vor der Korrektur des Schattendurchgangs; QA-mid sollte ihn mit dem Endstand ansehen.

## 9. Lieferung (`deliver/R7c/`)

| Datei | Inhalt |
|---|---|
| `ab/hh_*`, `ab/nu_*`, `ab/pa_*`, `ab/am_*`, `ab/be_*`, `ab/ly_out_*` | Stadteinfahrten Hamburg, Nürnberg, Paris, Amsterdam, Bern, Lyon-Vorort – Arcade \| Modern, Hoch 12 Uhr, Mittel 19:30, Hoch 22 Uhr (Nürnberg und Paris auch Mittel 12 Uhr) |
| `ab/daemmerung_hh_medium_h19*` / `h22` | Hamburg Mittel 19:00, 19:30, 22:00 |
| `ab/wald_*` | Waldstrecke Dortmund – Frankfurt km 48–50, Hoch / Mittel 12 Uhr, Mittel 22 Uhr, je zwei Zeitpunkte |
| `daemmerung_hamburg_1930.jpg` | Arcade \| Basis \| R7c um 19:30 (Fensterlicht) |
| `basis_*.jpg` | Arcade \| Basis \| R7c an derselben Stelle (Paris, Nürnberg, Lyon-Vorort, Wald) |
| `clip_paris_einfahrt_mittel.mp4`, `clip_nuernberg_fachwerk_mittel.mp4` | 20-s-Clips Arcade \| Modern bei „Mittel“ |
| `clip_*_spitze.jpg` | die vier Bilder um die größte Spitze je Clip (Bewegung, kein Stufenwechsel) |
| `lod_mitte_vorher.jpg` | der Fehler, den `check_lod_band` im ersten Lauf fand (Schattendurchgang, behoben) |
| `modern_goldens_basis_r7c_differenz.jpg` | die sechs Modern-Goldens: Basis \| R7c \| Differenz × 4 |
