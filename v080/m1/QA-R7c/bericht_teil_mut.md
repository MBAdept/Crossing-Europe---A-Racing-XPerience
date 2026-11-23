### 3.3 Wachen die neuen Tests über ihre Regeln? (Mutationen, gemessen)

In einer Kopie des Endstands (`m1/QA-R7c/mut`, `git archive bd1803b`) je Regel eine Zeile gebrochen, dann
`tests/run_tests.gd -- --filter=test_props` (Unit) bzw. `tools/run_render_checks.sh modern <datei>` (Render), danach die
Datei zurückgesetzt (`sh/mutate.py`, Logs `mutlogs/`). Ohne Mutation: `test_props` 18/18 grün.

| Nr. | Regel (Leitentscheid) | Mutation (eine Zeile) | Ergebnis |
|---|---|---|---|
| U1 | Bänder der Nachbarstufen schließen aneinander (1) | lod1 blendet ab `d0` statt `d0 − w0` ein | **gefangen** – `test_lod_bands_per_model`, `test_chunk_lod_shows_one_representation` |
| U2 | Stück schaltet Stufenknoten ohne Instanz im Band ab (1, Leistung) | `n3.visible = true` | **gefangen** – `test_chunk_lod_shows_one_representation` |
| U6 | Anbauten links gespiegelt (6) | `ox := off.x` | **gefangen** – `test_model_attachments` |
| U11 | lod0-Ersatz je Tag (`tag:city`, 1) | Tag-Ersatz gibt 0 | **gefangen** – `test_lod_bands_per_model` |
| U3 | Phase je Instanz (7) | `instance_phase()` gibt immer 0 | **nicht gefangen** (18/18 grün) – alle Rotoren und Kronen schwingen gleichphasig |
| U8 | Wiegen der Bäume ohne Sprung beim Verschieben des Ursprungs (7) | `leaves.gdshader`: Phase wieder aus der Weltlage | **nicht gefangen** – der Sprung bei jedem 2-km-Verschieben wäre zurück |
| U4 | `ground_sink` (7, A-16) | Absenkung abgeschaltet | **nicht gefangen** (der Test prüft nur „≤ Boden am Anker“) |
| U5 | `ground_align` (7, A-16) | Neigung abgeschaltet | **nicht gefangen** |
| U7 | Fernlicht-Wert aus der Konfiguration erreicht das Material (2) | `far_sun` immer 1,0 | **nicht gefangen** |
| U10 | Angebaute Bäume fallen im Kurvenkorridor weg wie jeder Baum (6, F7) | `attached` überspringt `drop_reason()` | **nicht gefangen** |
| R5 | Alphatest aus gröberer Mip (3) | `texture(albedo_tex, UV)` ohne `cutout_bias` | **nicht gefangen** (`test_props`) |
| R6 | Fernbild nachts ohne Relief (5) | `relief_night` wirkungslos | **nicht gefangen** (`test_props`) |
| R1–R4 | Raster, Schattendurchgang, Fernlicht-Gesetz, Fensterdeckung | siehe 3.4 (Render-Prüfungen) | |

Urteil (mit 3.4: 6 von 17 Mutationen gefangen): Die Mechanik der Bänder (Leitentscheid 1) ist gut bewacht, die Anbau-Spiegelung auch. **Fernlicht (2),
Flimmern (3), Relief (5), Phase/Tags (7) und die Korridorregel der Anbauten (6) haben keine Wache, die bricht**, wenn man
sie abschaltet (Befund QR7c-02).
