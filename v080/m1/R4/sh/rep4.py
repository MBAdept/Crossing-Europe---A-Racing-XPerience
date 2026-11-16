p = '/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R4/bericht.md'
s = open(p).read()
WARM = ('**OK auf `7f0eae2`** (`warmup_cold.gd`, leerer Mesa-Cache und Nutzerordner, „Mittel“, 30 s): N1 22 Uhr Schnee 443 '
        'Varianten vor dem Start, **0 während der Fahrt**, längstes Bild 2.994 ms bei Median 1.415 ms (Grenze 4.246 ms); '
        'N2 16 Uhr Regen 455 Varianten, 0 während der Fahrt, längstes 4.463 ms bei 1.802 ms (Grenze 5.406 ms). Der erste '
        'Lauf auf `83dbdac` fiel bei N1 durch (3 Varianten nach 8,2 s) – Ursache und Abhilfe in 1.12')
REST = '''## 4. Tore auf dem Endstand (gemessen; Befehle aus dem Worktree, `XDG_DATA_HOME` absolut, nice 19/10)

| Tor | Befehl | Ergebnis |
|---|---|---|
| Import | `godot --headless --path . --import` | sauber, Exit 0 (28 s) |
| Skripte | `godot --headless --path . -s res://tests/check_scripts.gd` | „318 Skripte geprüft, 0 fehlerhaft“ |
| Tests (Vollauf 2 von 2, `866a74c`) | `tools/run_tests.sh` | 761 Einheitstests, **1 rot**, dazu `check_modern_stage` **rot** – beide Last (Last 15–20, sechs Agenten): (a) `test_modern_checks` „mit Wiedergabe“: Sitzung in 89 von 99 Bildern (< 90 %), Arcade-Bild, kopflos – nichts von R4; einzeln nachgefahren `tools/run_tests.sh test_modern_checks`: **3 von 3 grün** (129 von 136 Bildern); (b) `kern_zeit`: Einhängen eines Stücks 4,07 ms > 3 ms – der Kern-Test benutzt nur Straße/Randstreifen/Hintergrund/Licht/Overlay; im Wechsel nachgemessen (`--only=kern_zeit`): Kopf 1,59 / 1,58 ms, Basis `6e48405` 1,50 / **3,00 ms** (die Basis fiel einmal selbst durch) – Rauschen. Alles andere grün (u. a. `test_light_pool`, `test_weather`, `test_environment_rig`, `test_far_ground_water`, `test_props`) |
| `test_light_pool` auf `7f0eae2` | `tools/run_tests.sh test_light_pool` | 7 von 7 grün (neu: Aufwärm-Ebene) |
| Render-Prüfungen | `RENDER_CHECK_TIMEOUT=2400 tools/run_render_checks.sh all` (`866a74c`) | **„23 von 23 Render-Prüfdateien in Ordnung“** – darunter `check_start_km0`, `check_terrain_cover` (T1–T4, S1, C1, **K1**: 0,000 % Magenta), `check_light_base`, `check_night` (4 OK), `check_weather` (5 OK), beide Tabellen, `check_instance_budget_wald` (2.253 s, knapp unter 2.400 s); auf `7f0eae2` erneut `check_facade_render` (5 OK, `aufwaermen` mit Ebene 20) |
| Arcade gleich | `tools/golden.sh check` (`866a74c`; danach nur Modern-Dateien geändert) | **„GOLDEN arcade: 20 von 20 identisch“**, **„GOLDEN arcade-ui: 17 von 17 identisch“**@@GOLDEN2@@ |
| Modern-Änderungsmelder | `tools/golden.sh modern-check` (`866a74c`) | 0 von 6 identisch – gewollt (Sonnenscheibe, Himmelsspiegelung, Halbkugel-Licht, Nacht-Füll-Licht, Mond); alle sechs Bilder angesehen (`m1/R4/modern_golden_new.jpg`), dann `modern-make` (Hashes = Bilder der Prüfung), Commit `83dbdac`; OpenGL-ES-Stufe OK (höchstens 2/255, PSNR 73,2 dB); auf `7f0eae2` `modern-check modern_s1_nacht`: **1 von 1 identisch** (die Lichtebene ändert kein Bild) |
| Sicht | `godot --headless --path . -s res://tests/sim/modern_sight.gd -- --full` | alle OK: f1 0 Fälle bis 270 m, f1 Außenspuren 0 bis 260 m, f2 ≤ 0,596, f3 0 von 5.923 Zielen später, f7 0 Seiten, Modell 0 abweichend (254 s) |
| Weg | `godot --headless --path . -s res://tests/sim/modern_path_check.gd -- --full` | OK: kleinster Abstand 267,6 m (≥ 250), Schleifen frühestens nach 2.064 m (≥ 2.000) |
| Ganze Etappe | `tests/race/run_stage.gd` (Kiel – Hamburg, 21 Uhr, Regen, „Mittel“, Zeitraffer 4) | @@STAGE@@ |
| Warm-up kalt | `tests/race3d/render/warmup_cold.gd` N1, N2 | siehe Abschnitt 2 |

## 5. Leistung (llvmpipe unter Xvfb, gemessen; echte Grafikchips und Steam Deck: abgeleitet)

@@BENCH@@

## 6. Clips (60 fps fest, 20 s, „Hoch“, A/B)

@@CLIPS@@

## 9. Für die nächsten Pakete

Siehe Ergebnis (`notes_for_next`); ausführlich:
1. **R5**: der Tunnel-Builder ruft in `update()` `renderer.get("env").set_zone("tunnel", amount)` (duck-typed, `has_method`);
   ab dem ersten Aufruf gilt nur noch der gesetzte Wert. Die Belichtungsrampe braucht Builder „tunnel“ und die Röhre als
   Verdecker des Vierecks. Tunnellampen brauchen eine Pool-Reichweite (`range` in `add_lamps`), sonst zählen sie nicht
   zum Punktlicht-Pool. Brücken über Wasser: `set_zone("bridge", 0…1)` (Wind bis +50 %).
2. **R6**: `add_lamps()` und seine Rollen sind unverändert; `builders/props.gd` unverändert (Einzeiler für eigene
   Bauteile beim Zusammenführen behalten).
3. **FIX-M2 / Zusammenführung**: FIX-M2 (B-03 Blaulicht, B-05 Abblendlicht, B-06 Lack) arbeitet auf derselben Basis in
   R4-Dateien (`vpbr.gdshader`, `modern_materials.gd`, `layers/{vehicles,lights,flares}.gd`) – Konflikte erwartet; R4
   hat `VEHICLE_LOOK` (hemi_side/down, fill_night/sheen/sheen_tint/tunnel/shade) und `fill_*`-Uniforms neu.
4. **Lack (offen)**: der silberne GT nachts im Regen – Kofferraumdeckel und Dach rund 1,6 × Arcades Wert (Raster),
   vermutlich der Klarlack, der unter flachem Winkel den Regenhimmel spiegelt (`env_night` 0,35); Dämmerung: die
   Limousine spiegelt den lila Himmel (unten Sättigung 0,8 ×, +7 % hell). Nicht mehr angefasst, weil jede Änderung
   an `vpbr` den Lauf aller Render-Prüfungen (2 h 10 min) und der Modern-Hashes verlangt hätte.
5. **R7**: Zeitfaktor in `billboard.gdshader` gegen das Relief der Impostoren in Dämmerung/Nacht (A-10, nicht gemacht).
6. **Modellpakete**: Fern-Konstanten (`TRAFFIC_GLASS_FAR`, `FAR_PLATE`, `GLASS_FAR`, `CHECK_MEAN_EXP`) gegen den
   geänderten `VEHICLE_LOOK` (hemi_side 0,72 / hemi_down 0,5 für vpbr und glass) nachmessen.
7. **Prüfdauern** (Last 15–20): `check_instance_budget_wald` 2.253 s von 2.400 s – bei mehr Last Zeitlimit;
   `check_weather` 941 s, Tabelle 621 s + 302 s, `check_night` 435 s.
'''
for o, n in [('@@WARM@@', WARM), ('@@REST4@@', REST)]:
    assert s.count(o) == 1, o
    s = s.replace(o, n)
# 1.12: the warm-up layer, after 1.11
anchor = '## 2. Prüfungen (gemessen)'
add = '''### 1.12 Aufwärmen nachts (Entscheidung 7) – `7f0eae2`
Die Aufwärm-Prüfung mit kaltem Cache fiel bei N1 durch: 3 Shader-Varianten nach 6–8 s Fahrt (vier Läufe, immer
dieselben drei Mesa-Dateien). Eingegrenzt: N1 um 14 Uhr 0, um 22 Uhr ohne Schnee 3 – also die Nacht. Godots eigener
Shader-Cache (Datei mit dem Zeitstempel der Übersetzung) zeigte das Programm: `sign.gdshader` (Uniforms
`back_colour`, `retro`, `hl_range`). Ursache: nachts brennt das Abblendlicht schon beim Aufwärmen und beleuchtete die
Aufwärm-Knoten (14 m voraus) in allen vier Phasen – die Variante „ohne positionelles Licht“ entstand nur für
Materialien, die die Startansicht fern zeigt; N1 hat dort kein Schild. Abhilfe: die Aufwärm-Knoten liegen auf
Render-Ebene 20 (`ModernRenderer.WARMUP_LAYER`, Boden-Knoten behalten ihre Ebene), die echten Spots und Punktlichter
lassen sie aus (`lights.gd` `LIGHT_MASK`), nur die Aufwärm-Lichter erreichen sie. Danach N1 443 statt 386 Varianten vor
dem Start und 0 während der Fahrt; das Nachtbild der Modern-Hashes bleibt gleich (kein Objekt liegt sonst auf Ebene 20).
Unit-Test `test_warmup_layer_is_lit_by_the_warmup_lights_only`.

'''
assert s.count(anchor) == 1
s = s.replace(anchor, add + anchor)
open(p, 'w').write(s)
print('ok')
