## 7. Befunde (blocker = nicht in Testbuild 2; hoch = fällt sofort auf; mittel = merklich; niedrig = Feinschliff)

Kein Blocker, kein hoher Befund. Arcade-Identität, Sicht (F1–F3, F7), Tests und Render-Prüfungen sind grün; R7c stellt
im ganzen Netz keine Requisite um und nimmt keine weg.

### QR7c-01 (mittel) – „Steam Deck“/„Mittel“: Stadthäuser ab 35 m in lod1, Details flacher als vorher

- **Wo:** `config/game_config.json` `graphics.modern.props.lod0_m` = `{"tag:city": 35, Fachwerk/Paris: 30}`; wirkt über
  `props.gd lod0_override()` auf **alle 28 Modelle mit Tag `city`** (auch Speicher, Kontor, Gründerzeit, Bauten von
  AS4 wie `building_block_a/b`, `building_tall`).
- **Was:** Leitentscheid 1 nannte „etwa 35 m für Fachwerkhäuser gegen das Balkenflimmern“; R7c kürzt lod0 aller
  Stadthäuser. Bei „Steam Deck“ (Details Mittel) zeigt Hamburg bei 35–60 m die Stufe 1: **die grünen Ladetüren des
  Speichers sind flache grüne Flächen statt Kassetten, die Fenster flacher** – gleich dem Arcade-Sprite, aber schlechter
  als Basis und 43a1fcc, die dort lod0 zeigten (ganze Stücke lod0 bis 60 m Wegabstand).
- **Beleg (gemessen + angesehen):** `deliver/QA-R7c/raw/hh_deck_h12_tri_00.jpg`, Ausschnitt
  `deliver/QA-R7c/hamburg_deck_speicher_43a1fcc_r7c.png` (links 43a1fcc, rechts R7c); 2,5 % der Pixel gegen Basis und
  43a1fcc (bei Hoch nur 0,2 %, dort endet lod0 bei 70 m). Studio-Vergleich lod0 | lod1 | Sprite bei 32/40/50 m:
  `deliver/QA-R7c/lod0_lod1_sprite_mittel_32-50m.png` (Speicher-Zeilen: lod1 = Sprite-Niveau; Kontor, Fachwerk,
  Haussmann, Block A: lod1 fast gleich lod0).
- **Nachstellen:** `sh/tri.sh … hh_deck_h12 deck --stage=kiel_hamburg --from=kiel --start-km=88.2 --hour=12 …
  --start-speed=50 --shot-times=2,4`, rechtes Gebäude vergleichen.
- **Fix:** `lod0_m` nur für die Modelle, deren lod0 nachweislich über 2 × Sprite flimmert (Fachwerkzeile, Fachwerkzeile B,
  Haussmann, Pariser Eckhaus: 30 m); `tag:city` streichen oder auf ≥ 50 m setzen und Speicher/Kontor einzeln messen –
  oder im Asset-Paket die Kassetten der Türen und Fensterlaibungen in den Atlas von lod1 backen (lod1 des Speichers hat
  1283 statt 8950 Dreiecke und flache Türen).

### QR7c-02 (mittel) – Fernlicht, Flimmern, Fernbild-Relief, Phase, Tags und Anbau-Korridor ohne Wache

- **Wo:** `tests/unit/race3d/test_props.gd`, `tests/race3d/render/check_lod_band.gd`.
- **Was:** 11 von 17 Mutationen bleiben grün (Abschnitt 3.3/3.4): Fernlicht im Shader aus (R3) oder `far_sun` nicht aus
  der Konfiguration (U7), Alphatest ohne `cutout_bias` (R5), Fensterdeckung aus (R4), Relief nachts nicht
  zurückgenommen (R6), Phase konstant (U3), Wiegen wieder aus der Weltlage – der Sprung beim 2-km-Verschieben wäre
  zurück (U8), `ground_sink`/`ground_align` wirkungslos (U4/U5), angebaute Bäume im Kurvenkorridor nicht weggelassen
  (U10, F7-relevant, sobald ein Modell `attach` nutzt), Schattendurchgang mit Raster (R2).
- **Beleg (gemessen):** `m1/QA-R7c/mutlogs/mutate.out`, je Mutation `<id>_test_props.log` / `<id>_check_*.log`.
- **Nachstellen:** `python3 m1/QA-R7c/sh/mutate.py <id>` (Kopie `m1/QA-R7c/mut`).
- **Fix:** (a) `test_props`: nach `commit()` eines werfenden Gebäudes `far_sun`/`shadow_far` des Materials = Wert der
  Konfiguration (Klasse und Modell); (b) Shader-Texttests ohne Kommentare (wie `STATIC_MARKERS`): `leaves` liest die
  Phase aus `INSTANCE_CUSTOM.a`, `baked_cutout` testet mit `cutout_bias`, `billboard` nimmt `relief_night × ce_night`,
  `baked` setzt `cover_k` in `ALBEDO`; (c) zwei Windräder verschiedener Items haben verschiedene Phasen; (d)
  `sink_height` an einem Hang liefert den tiefsten Punkt (konkreter Wert), `align_basis` neigt; (e) Anbau-Test mit einer
  Kurve: die angebaute Eiche im Korridor fällt weg (`dropped.corridor`); (f) Render-Prüfung „Fernlicht“: Haus bei 60 /
  140 / 250 m, Luma in ±5 % (wie `k6_scene --mode=lodcol`), mit abgeschaltetem `far_sun` rot.

### QR7c-03 (niedrig) – Haken von `props.gd`: 2,5–3× teurer, Spitzen 3,8–4,4 ms bei „Steam Deck“

- **Wo:** `scripts/race3d/builders/props.gd` `update()` 359–371, `_apply_lod()` 1207–1227, `_span()` 1231–.
- **Was:** alle 2 m Fahrt rechnet jedes Stück Kasten und 8 Ecken; `span_key` (auf 1 m gerundet) ändert sich bei jedem
  Schritt, also läuft die Schleife über alle Kindknoten aller Stücke, auch wenn kein Band gekreuzt wird.
- **Beleg (gemessen):** Abschnitt 6 – Haken Mittel 0,25–0,32 ms (vorher 0,10), Max 3,82 / 4,44 ms in zwei KH-Deck-Läufen
  (43a1fcc 0,47 / 0,59, Basis 1,20); Einhängen 2,3–2,8 ms (vorher 1,7–1,9; Budget Deck 3,0). Lärm der geteilten VM möglich,
  aber in beiden Läufen.
- **Fix:** je Stück die nächste Entfernung merken, an der ein Knoten sein Band betritt oder verlässt (min über die
  Kinder von |span − Bandkante|) und erst dann die Kinder durchgehen; Weltkasten nur beim Verschieben des Ursprungs neu;
  höchstens N Stücke je Bild (Rundlauf).

### QR7c-04 (niedrig) – Ferne Fassaden weicher: Farb-Mip-Bias macht weiße Fensterrahmen grau

- **Wo:** `props.gd PROP_LOOK` `albedo_bias` 1,25 (ab 30 m, voll bei 120 m), `baked.gdshader` 95.
- **Was:** im Standbild ist das ferne Bürgerhaus in Nürnberg (~100 m) weicher als in der Basis und in Arcade: die weißen
  Fensterrahmen werden grau, die Fassade wirkt verwaschen; der Gewinn (weniger Flimmern in Bewegung) ist im Standbild
  nicht zu sehen.
- **Beleg (angesehen):** `deliver/QA-R7c/raw/nu_high_h12_tri_00.jpg`, Ausschnitt 3× `m1/QA-R7c/tmp/nz.png`
  (Arcade | Basis | R7c); Diff-Bild `nu_high_h12_diff_00.jpg` (nur dieses Haus und Rahmen geändert).
- **Fix:** `albedo_bias` 0,75 oder erst ab 60 m; den Mip-Bias nur auf die Kanäle mit dünnen Linien (Fachwerk) setzen,
  nicht auf alle Stadthäuser.

### QR7c-05 (niedrig) – Stufenknoten werden bis 2 m zu spät eingeschaltet (Rasterlöcher möglich)

- **Wo:** `props.gd` 364 (`LOD_STEP_M` 2 m) und 1225 (`span.x <= b.w` ohne Spielraum).
- **Was:** kommt eine Instanz zwischen zwei Prüfungen in das Band einer feineren Stufe, ist deren Knoten noch aus,
  während die gröbere schon ausblendet: bis 2 m Fahrt fehlen bis 2/(2 w) der Pixel (Stadthaus „Mittel“: w = 4,2 m → 24 %).
  Gefolgert, im Bild nicht gesehen – der Kasten der Instanz-Ursprünge liegt meist näher als das Haus und fängt es ab.
- **Fix:** `n3.visible = span.y >= b.x - LOD_STEP_M and span.x <= b.w + LOD_STEP_M` (eine Zeile).

### QR7c-06 (mittel) – Raster steht still, wenn der Wagen steht (Countdown, Stau, Polizei)

- **Wo:** `inc/lod_band.gdshaderinc` `ce_lod_discard()` – das Band hängt am Weg, nicht an der Zeit (Abweichung von A-16
  „0,3–0,5 s wie `xfade`“).
- **Was:** steht ein Baum oder Haus beim Stand im Band (Bäume „Mittel/Deck“ 53–67 m, Stadthäuser 31–39 m, Hoch
  doppelt so weit), bleibt es im geordneten Raster zweier Stufen stehen: die Krone wirkt gesprenkelt/körnig. Beim
  Countdown jeder Etappe sichtbar, sobald dort Bäume stehen.
- **Beleg (gemessen + angesehen):** Start Nürnberg – Fulda km 0, Countdown 1,5 s, Deck:
  `deliver/QA-R7c/raw/start_nu_deck_h12_tri_00.jpg`, Ausschnitt 2× `deliver/QA-R7c/start_countdown_deck_raster_basis_r7c.png`
  (links Basis glatt, rechts R7c: Eiche unten rechts gerastert); 0,3 % Pixel gegen die Basis.
- **Nachstellen:** `SCREEN=1280x800 sh/tri.sh <out> deck --stage=nuernberg_fulda --from=nuernberg --start-km=0 --hour=12
  --weather=normal --vehicle=limousine --seed=11 --autopilot --autopilot-refuel=never --traffic-warmup --shot-times=1.5`.
- **Fix:** ein globales `ce_lod_still` (0..1, vom Renderer aus der Kamerageschwindigkeit, z. B. < 2 m/s → 1) im Shader:
  bei stehender Kamera die Bandbreite auf 0 ziehen (harte Entscheidung in der Bandmitte, kein Raster) – oder die Leitung
  nimmt das Raster im Stand hin (Vertragsfrage 2).

### QR7c-07 (niedrig, Zusammenbau) – Konflikt mit FIX-RINT in `test_props.gd`

- **Wo:** `tests/unit/race3d/test_props.gd` (`git merge-tree bd1803b origin/wip/v080-fix-rint` → Konflikt), beide
  ändern `test_model_instances_carry_the_placement_tint` / `test_chunk_lod_shows_one_representation`.
- **Fix (Leitung):** beide Fassungen behalten: FIX-RINTs `_code_only()`-Prüfung der Multiplikation und R7cs Phase in
  Custom-a (`assert_between(buf[19], 1.0, 1.999)`); danach `tools/run_tests.sh test_props`.

### QR7c-08 (niedrig, latent) – Anbauten jenseits des Stücks lesen den Boden der Randreihe

- **Wo:** `props.gd attach_item()` 907–919, `_place()`.
- **Was:** ein Anbau bei `z − off.z × sc` hinter der letzten Reihe des Stücks bekommt `ctx.ground()`/`drop_reason()` der
  Randreihe (Höhe am Hang falsch, Korridor der falschen Reihe); mehr als 8 Anbauten je Modell kollidieren in der
  Item-Nummer (`item * 8 + k`). Kein ausgeliefertes Modell nutzt `attach`.
- **Fix:** Anbauten mit `z` außerhalb `[seg_a, seg_b)` dem Nachbarstück überlassen (oder dort nicht stellen);
  `k < 8` prüfen.
