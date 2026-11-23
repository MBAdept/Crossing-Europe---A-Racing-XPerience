# FIX-R7c – Nacharbeit nach der unabhängigen Prüfung von R7c (Fern-LOD der Bauten und Pflanzen)

- Basis: R7c `bd1803b` (`origin/wip/v080-r7c`), Prüfbericht `deliver/QA-R7c/bericht.md` (8 Befunde: 3 mittel, 5 niedrig,
  kein Blocker). Arbeitsbaum `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_ba4424b4-294-10`,
  Zweig `worktree-wf_ba4424b4-294-10`, gesichert als `origin/wip/v080-fix-r7c`. Endstand: ENDSTAND.
- Vergleichsbaum für die „vorher“-Messungen: `m1/FIX-R7c/ref` (= `git archive bd1803b` + `.godot`, importiert). QAs
  Bilder ließen sich daraus **bit-genau** nachstellen (Hamburg Deck 12 Uhr, zwei Bilder, und der Countdown Nürnberg –
  Fulda: 0 Pixel Unterschied, `compare -metric AE`) – die Spalte „R7c“ der Bildvergleiche ist QAs Bild desselben
  Simulationsstands.
- **gemessen** = auf dieser VM (llvmpipe unter Xvfb, 4 Kerne geteilt mit anderen Agenten); **angesehen** = Urteil nach
  Bildern; **gefolgert** = hier nicht messbar (echte GPU, Steam Deck, Wirkung auf einen Menschen).
- Dateien (alle im Besitz von R7c laut Brief): `scripts/race3d/builders/props.gd`, `scripts/race3d/modern_materials.gd`
  (eine Zeile in `GLOBALS`), `assets/shaders/modern/inc/lod_band.gdshaderinc`, `config/game_config.json`
  (`graphics.modern.props` und der `_doc`-Text), `docs/renderer-modern-gelaende.md` §9, `tests/unit/race3d/test_props.gd`,
  `tests/race3d/render/check_lod_band.gd` und `tests/golden/modern_slice.*` (nach Ansicht erneuert, Abschnitt 5). Keine eingefrorene Datei,
  kein `environment_rig.gd`, keine fremde Datei.

## 1. Ergebnis in Kürze

- **Alle acht Befunde behoben**, die drei mittleren zuerst, jeder vorher nachgestellt (gemessen bzw. bit-genau
  nachgerendert) und nachher wieder angesehen bzw. gemessen.
- **QR7c-01:** Stadthäuser behalten ihr lod0 bis 60 m („Mittel/Deck“); nur Fachwerkzeilen, Haussmann und Pariser Eckhaus
  enden bei 30 m. Der Hamburger Speicher hat bei „Steam Deck“ wieder seine Kassettentüren (Bild).
- **QR7c-06:** neues globales `ce_lod_still` – bei stehender Kamera (unter 1,5 m/s) zieht sich jedes Band in 0,4 s zu
  seinem fernen Ende zusammen: kein Raster im Countdown, im Stau, beim Polizeistopp, und im ganzen Band steht die
  feinere Stufe (die Eiche im Countdown sieht aus wie in der Basis). Render-Prüfung: 0,00 % Abweichung vom harten Wechsel.
  Die Uhr der Rampe ist `view.time` (dieselbe Ansicht zweimal gezeichnet gibt dasselbe Bild – `check_weather` hatte
  das bei der ersten Fassung mit `dt` gefunden).
- **QR7c-02:** acht neue Tests und drei neue Fälle in `check_lod_band` (zweimal „…_stand“, „fernlicht“); **alle 17
  Mutationen von QA-R7c und sechs neue werden gefangen** (vorher 6 von 17).
- **QR7c-03:** Haken von `props.gd` auf Kiel – Hamburg „Steam Deck“: Mittel 0,148 / 0,155 ms statt 0,282 / 0,264 ms,
  Max 0,50 / 1,00 ms statt 3,61 / 2,93 ms (je zwei Läufe, gemessen); Einhängen max. 1,92 / 2,78 statt 3,18 / 2,04 ms.
- **QR7c-04:** Farb-Mip-Bias je Modell: Fachwerk ab 30 m, alle anderen erst ab 60 m (voll bei 150 m) – die weißen
  Fensterrahmen in Nürnberg (~100 m) sind wieder scharf, das Flimmern bleibt für die gemessenen Häuser ≤ 2 × Sprite
  (außer dem Kontor, das mit jedem Bias 4–5 × flimmert – Geometrie).
- **QR7c-05/-07/-08:** Spielraum der Stufenknoten; `git merge-tree` mit FIX-RINT, FIX-R7a, FIX-R7b ohne Konflikt;
  Anbauten jenseits des Stücks nicht gestellt, höchstens 8 je Modell.
- **Gates (Abschnitt 5):** GATESKURZ

BEFUNDE

## 4. Leistung – ganze Etappe Kiel – Hamburg mit Autopilot, „Steam Deck“ 1280×800 (gemessen)

`tests/race/run_stage.gd -- --graphics=modern --gfx-preset=deck --stage=kiel_hamburg --from=kiel --vehicle=limousine
--hour=12 --weather=normal --seed=11 --timescale=20`, Xvfb, llvmpipe, gemeinsamer Mesa-Cache (je Baum ein Aufwärmlauf
Würzburg – Nürnberg verworfen), abwechselnd FIX-R7c (`fix`) und R7c `bd1803b` (`ref`) – `sh/perf.sh`, Logs
`m1/FIX-R7c/perf/`. Zeichenaufrufe und Primitive: letztes Bild (Ziel in Hamburg).

PERFTABELLE

- **Haken `props`:** im Mittel halbiert (0,15 statt 0,27 ms), Spitzen 0,5–1,0 statt 2,9–3,6 ms. Er liegt noch über den
  0,10 ms vor R7c (QA): die Spanne jedes Stücks wird weiter alle 2 m gerechnet (ein `AABB`-Transform und zwei
  Vektorrechnungen je Stück) – über die Kinder läuft er nur noch an Schwellen.
- **Primitive im Zielbild +21 %** (165 471 statt 136 993): die Hamburger Stadthäuser zeigen bis 60 m wieder lod0
  (QR7c-01); 43a1fcc (vor R7c) hatte dort 158 344 (QA). Weit unter dem Deck-Budget von 450 000 (§4.10). Zeichenaufrufe
  138 statt 132 (Budget 650).
- `render()` Mittel 3,00 / 3,08 ms gegen 3,31 / 3,11 ms – gleich im Rahmen des Lärms; Bildzeit gleich.
- `collect()` aller Bausteine max. 2,9–3,9 ms – in beiden Bäumen über den 2 ms von A-18 (der Anteil von `props` ist
  0,08 ms; nicht von R7c/FIX-R7c, notiert).
- `ERGEBNIS` aller Läufe identisch (time_s 326,3; Regel 3), 0 Fehlerzeilen.

## 5. Gates auf dem Endstand

GATES

## 6. Bilder (angesehen; Arcade | R7c `bd1803b` | FIX-R7c, gleicher Simulationsstand)

BILDER

## 7. Abweichungen und Vertragsfragen

VERTRAG

## 8. Für die nächsten Pakete

NAECHSTE

## 9. Lieferung (`deliver/FIX-R7c/`)

LIEFERUNG
