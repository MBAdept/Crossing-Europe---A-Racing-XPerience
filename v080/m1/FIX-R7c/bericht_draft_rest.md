### QR7c-03 (niedrig) – Haken von `props.gd` teuer, Spitzen bis 4,4 ms → **behoben**

- **Nachgestellt (gemessen):** Kiel – Hamburg „Steam Deck“ mit `ref` (R7c): Haken `props` Mittel 0,28 ms, Max 3,61 ms
  (QA: 0,25–0,27 / 3,8–4,4).
- **Fix:** `_apply_lod()` geht nur noch über die Kinder eines Stücks, wenn dessen Spanne eine seiner Schwellen kreuzt
  (`_thresholds()`: Bandanfänge − 2 m gegen die fernste Instanz, Bandenden + 2 m und Reichweite der Schattenwerfer
  gegen die nächste, die Stufen der Meta „lod“; sortiert, `bsearch`). Vorher war der Schlüssel die auf 1 m gerundete
  Spanne, die sich bei jedem Blick änderte. Die fernste Ecke des Kastens ohne Schleife (je Achse das fernere Ende).
  `quality_lowered()` rechnet die Schwellen neu.
- **Nachgeprüft (gemessen, je zwei Läufe, gleiche VM, abwechselnd):** Tabelle in Abschnitt 4 – Haken `props` Mittel
  0,148 / 0,155 ms statt 0,282 / 0,264 ms, Max 0,50 / 1,00 ms statt 3,61 / 2,93 ms; Einhängen Max 1,92 / 2,78 statt
  3,18 / 2,04 ms. `ERGEBNIS` identisch (Regel 3). Test `test_chunk_lod_walks_only_at_thresholds`.

### QR7c-04 (niedrig) – ferne Fassaden weicher → **behoben (mit Maß)**

- **Nachgestellt (angesehen):** Nürnberg km 102,0 Hoch 12 Uhr: die weißen Fensterrahmen des Barockhauses (~100 m) grau.
- **Gemessen (sparkcam, lod1, „Mittel“, 60 / 100 / 150 m, Anteil kippender Pixel je Viertelpixel-Schritt):**

| Modell | ohne Farb-Bias | 1,25 von 30–120 m (R7c) | 1,25 von 60–150 m (FIX) | Sprite |
|---|---|---|---|---|
| Barockhaus | 0,2 / 0,5 / 1,0 | 0,2 / 0,2 / 0,4 | 0,2 / 0,3 / 0,4 | 0,1 / 0,3 / 0,4 |
| Grachtenhaus B | 0,4 / 0,5 / 0,9 | 0,3 / 0,3 / 0,5 | 0,4 / 0,4 / 0,5 | 0,2 / 0,2 / 0,4 |
| Speicher | 0,2 / 0,2 / 0,4 | 0,1 / 0,1 / 0,3 | 0,2 / 0,2 / 0,3 | 0,1 / 0,2 / 0,2 |
| Gründerzeit | 0,2 / 0,2 / 0,3 | 0,1 / 0,2 / 0,2 | 0,2 / 0,2 / 0,2 | 0,1 / 0,2 / 0,4 |
| Kontor | 0,3 / 0,5 / 0,9 | 0,2 / 0,5 / 0,9 | 0,3 / 0,5 / 0,9 | 0,1 / 0,1 / 0,2 |
| Fachwerkzeile | 0,2 / 0,6 / 1,1 | 0,2 / 0,4 / 0,9 | (bleibt 30–120 m) | 0,1 / 0,2 / 0,4 |

  Ganz ohne Bias (QAs erster Vorschlag „nur Fachwerk“) flimmern Barockhaus (2,5 × Sprite bei 150 m) und Grachtenhaus B
  (2,25 ×) über Leitentscheid 3 – deshalb bleibt der Bias, beginnt aber erst bei 60 m und ist bei 150 m voll (bei 100 m
  0,52 statt 1,09 Stufen). Das Kontor flimmert mit jedem Bias 4–5 × Sprite – Kanten der Geometrie (Asset-Paket).
- **Fix:** `graphics.modern.props.albedo_bias` = {"default": [1,25, 60, 150], Fachwerkzeile / B: [1,25, 30, 120]};
  `props.gd` setzt `albedo_bias` und `albedo_bias_m` je Modell (`albedo_bias_of()`), `PROP_LOOK` trägt den Bias nicht mehr.
- **Nachgeprüft (angesehen):** `nuernberg_hoch_fernhaus_arcade_basis_r7c_fix.png` (3×): die Rahmen sind wieder weiß und
  scharf wie in der Basis.

### QR7c-05 (niedrig) – Stufenknoten bis 2 m zu spät → **behoben**

`n3.visible = span.y >= b.x - LOD_STEP_M and span.x <= b.w + LOD_STEP_M` (QAs Zeile); Test
`test_chunk_lod_walks_only_at_thresholds` (lod0 schon 1 m vor seinem Band an) und Mutation U12 (ohne Spielraum: rot).

### QR7c-07 (niedrig) – Konflikt mit FIX-RINT in `test_props.gd` → **behoben**

Die Notiz über `test_chunk_lod_shows_one_representation` (R7c hatte zwei `##`-Zeilen genau dort eingefügt, wo FIX-RINT
`_code_only()` einfügt) steht jetzt in der Funktion; neue Tests am Dateiende, neuer Helfer heißt `_shader_code()`.
`git merge-tree --write-tree HEAD origin/wip/v080-fix-rint` (3248211): **Exit 0, kein Konflikt**; ebenso mit
`origin/wip/v080-fix-r7a` und `origin/wip/v080-fix-r7b` (gemessen). MERGETEST

### QR7c-08 (niedrig, latent) – Anbauten jenseits des Stücks → **behoben**

Ein Anbau, dessen z außerhalb [seg_a, seg_b) des eigenen Stücks läge, wird nicht gestellt (Boden und Kurvenkorridor wären
die der Randreihe; das Nachbarstück sieht das Haus nicht); höchstens `ATTACH_MAX` = 8 Anbauten je Modell (Nummern
`item × 8 + k` bleiben getrennt). Test im Test-Manifest (Haus 2 m vor dem Stückende, Anbau 6 m weiter: nicht gestellt),
Mutation U14 rot. Folge: Versätze von wenigen Metern verlieren den Anbau nur am Ende eines Stücks – notiert für das
Asset-Paket, das `attach` als erstes nutzt.
