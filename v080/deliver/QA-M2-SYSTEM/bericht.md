# QA-M2-SYSTEM – unabhängige Prüfung der ersten M2-Montage (Arcade-Identität, Klang, Modell-Pipeline, Robustheit)

- **Geprüfter Stand:** `6e484056ec87e2fa614061000a362feb2b5a6db8` (`origin/wip/v080-m2int` = `origin/wip/v080-m2zs1`, M2INT + ZS1-Merge),
  Prüf-Arbeitsbaum `.claude/worktrees/wf_438996b0-243-4` (fast-forward auf den Kopf, `.godot` kopiert und importiert,
  **keine Änderung, kein Commit**). Prüfkopien für Mutationen, Rückfall- und Export-Versuche: `m1/QA-M2-SYSTEM/mut`
  (`git archive` des Kopfes), v0.7.0-Referenz `git archive main` – beide, das Wine-Präfix und `build/` nach Gebrauch gelöscht; Skripte und
  Logs bleiben in `m1/QA-M2-SYSTEM/` (`bin/`, `gd/`, `q_*.log`, `mutations/`, `sound/`, `tyrewind/`).
- **Maschine:** 4 Kerne, llvmpipe (Software-OpenGL), Dummy-Audiotreiber, geteilt mit R4, R5, AS5a, QA-M2-BILD (Last
  meist 13–33). Alles über Steam Deck, echte GPU oder Hörempfinden ist **abgeleitet**; alle Zahlen unten sind
  **gemessen**, wo nicht anders gesagt.
- **Ablauf:** drei Durchgänge (Container-Neustarts am 13.11. 05:23 UTC während des Goldens und am 15.11. vor 08:03 UTC;
  die Nachfolger haben über `STAND.md` und die Logs übernommen). Der dritte Durchgang (15.11.) hat nachgeholt: die
  Waldprüfung bis zum Ergebnis, Wind/Reifen/Menüklänge einzeln, die Nachläufe der Mutationen, den Modern-Änderungsmelder
  und die Beenden-Fälle der laufenden Modern-Etappe.
- **Lesart:** „gemessen“ = an Datei/Log/Bild in diesem Lauf festgestellt; „abgeleitet“ = geschlossen, nicht gemessen;
  „gelesen“ = aus Berichten anderer Pakete übernommen und als solches gekennzeichnet.

## Zusammenfassung

**Urteil: kein Blocker, kein hoher Befund.** Der Kopf `6e48405` ist aus meiner Sicht für den nächsten Testbuild
tauglich, was Arcade-Identität, Klang, Modell-Pipeline und Robustheit angeht. Alle Zahlen sind auf dieser VM (llvmpipe,
Dummy-Audio, Last 13–33) **gemessen**; Hörempfinden, Steam Deck und echte GPU sind **abgeleitet**.

- **Arcade = v0.7.0:** 0 eingefrorene Dateien geändert; `ERGEBNIS` auf drei Etappen gleich (Kiel – Hamburg ganz,
  Bern – Mailand Schnee/Nacht, Dortmund – Frankfurt Regen/Dämmerung); Arcade-Klang-Fingerabdruck aus v0.7.0 neu erzeugt
  = Kopf; `golden.sh check` 20/20 und UI 17/17.
- **Klang Modern:** Kiel – Hamburg im echten Rennen: Betonplatten ab km 25,0 im 5-m-Takt, 4 Fugen der Köhlbrandbrücke
  genau an ihren Kilometern, Hamburger Pflaster/Asphalt genau nach den Blöcken; schwerer Unfall ≤ −4,1 dBTP bei
  Gesamtlautstärke 1,0 (Grenze −1); Rotation 1 → 2 → 3 → 1 mit Stingern und Zwischenspiel; „Musik im Rennen: Aus“ wirkt;
  Wind, Reifen und Menüklänge einzeln sauber; `audio_qc.py` 98/98; kein „leaked“.
- **Modell-Pipeline:** Manifest neu erzeugt byte-gleich, 87 Modelle = 87 Ordner; fünf Modelle neu exportiert und zweimal
  gebacken byte-gleich; `--check-keys` OK; Sprites 187/187 unverändert; Download Windows-Zip 194,5 MB (≤ 280).
- **Tests:** `run_tests.sh` 749/0; Render-Prüfungen 19/19 Dateien OK – die Waldprüfung aber erst nach 49 min mit
  erhöhtem Zeitlimit (M2S-01, mittel). Die beim Merge geänderten Tests werden bei je einer gebrochenen Zeile rot, mit
  drei Lücken (M2S-03 bis M2S-05, niedrig – die Regeln bewacht jeweils ein anderer Test oder der grep des Tors).
- **Robustheit:** `--gfx-debug=fail`, fehlendes/kaputtes Manifest und fehlende Netzdatei fallen auf Arcade zurück (Text
  nennt aber immer die Grafik, M2S-07); Leistungstest schreibt gültiges JSON; Beenden/Neustart in 14 Bildschirmen und in
  der Modern-Etappe (beim Laden: Absturzfrage, nach dem zweiten Mal Arcade; nach dem Zeichnen und im Pausenmenü: kein Marker, Neustart ohne Frage); 20 min Modern ohne Fehlerzeile, Speicher flach; Linux- und Windows-Build (Wine) fahren
  Arcade und Modern.

## Befunde

| ID | Schwere | Bereich | Wo | Was | Beleg | Nachstellen | Behebung |
|---|---|---|---|---|---|---|---|
| M2S-01 | mittel | Tor Render-Prüfungen | `tests/race3d/render/check_instance_budget_wald.gd` (erbt `check_instance_budget.gd`: `SIM_S` 100 s Sichtzeit bei Zeitraffer 6 ≈ 1 000 Bilder, gezeichnet in 480 × 270, Voreinstellung „Hoch“) unter `tools/run_render_checks.sh` (Zeitlimit 900 s je Datei) | Die Waldprüfung (Wächter des Shader-Puffer-Überlaufs `VPBR_STATIC` aus M2INT) braucht je nach Last der VM 8 bis 49 min. Das Tor „Render-Prüfungen“ wird so **rot ohne Produktfehler**, und ein echter Überlauf sähe im Protokoll genauso aus (Exit 124, keine Zeile) – A-11: „Eine Prüfung, die nur unter Last scheitert, ist eine kaputte Prüfung“. Die Produktregel selbst hält: Lauf 3 allein mit `RENDER_CHECK_TIMEOUT=3000` bestand nach **2 945 s** (49 min, Last 20–33; ganze Szene ≤ 142 Instanz-Uniforms, Fahrzeuge ≤ 127 von 128) – mit dem Standard-Zeitlimit wäre das Tor rot gewesen, und 55 s mehr Last hätten auch das erhöhte Limit gerissen. | Lauf 1: `RENDER-CHECK-DATEI …wald.gd FEHLER (Exit 124, 900 s)`, „Zeitlimit von 900 s überschritten“, keine Prüfzeile (`render_checks.log`); Lauf 2 mit `RENDER_CHECK_TIMEOUT=3000`, Last 20–22: nach 21 min ohne Ergebnis abgebrochen; Lauf 3 (15.11.) `RENDER-CHECK-DATEI …wald.gd OK (Exit 0, 2945 s)` (`q_wald.log`, gemessen). Laufzeiten derselben Datei in den Logs von M2INT/M2ZS1: 472 → 575 → 789 → 825 s (gelesen) | `tools/run_render_checks.sh modern instance_budget_wald` bei Last ≥ 15 | Die Bildgröße ist nicht der Hebel (schon 480 × 270). Die Sichtzeit der Wald-Variante kürzen (`SIM_S` überschreibbar machen, z. B. 30–40 s: der Wald bei km 46,5 ist ab dem ersten Bild da, der Überlauf hängt an gleichzeitig gezeichneten Instanzen, nicht an der Dauer – abgeleitet) und die Laufzeit je Phase (Laden/Fahren) ausgeben; Ziel < 300 s bei Last 20. Zusätzlich: `run_render_checks.sh` liest ein eigenes Zeitlimit aus einer Kopfzeile der Datei und meldet Exit 124 als „ZEITLIMIT (kein Ergebnis)“ statt als FEHLER der Regel. |
| M2S-02 | niedrig | Prüfabdeckung | `tests/race3d/render/check_vehicle_standin.gd` | Seit jedes Fahrzeug-Set ein Modell hat (AS2R), bestehen „spieler“, „verkehr“, „kasten“, „nacht“ und „verdeckt“ **leer** („… hat ein Modell (übersprungen)“, „kein … mehr ohne Modell – nichts zu vergleichen“); das Ersatzbild nach A-9 (Arcades Bild eines Sets ohne Modell, Rückfall §4.6.7) vergleicht keine Render-Prüfung mehr – nur „laden“ prüft noch. Kopflos bewacht `check_vehicles` „kasten“ den Weg (Mutationen rot, Abschnitt 4), das Bild selbst nicht. | `render_rest.log` (gemessen) | `tools/run_render_checks.sh modern vehicle_standin` und die Meldungen lesen | Wie `check_vehicles.gd` „kasten“ ein Test-Manifest laden (`"root"`), das einem Spieler-, einem Verkehrs- und einem Kasten-Set das Modell nimmt, und die fünf Vergleiche damit laufen lassen; „OK“ ohne Vergleich als FEHLER werten. |
| M2S-03 | niedrig | Prüfabdeckung | `tests/race3d/check_vehicles.gd` „leistung“ (beim Merge geändert) | Die Regel „kein Knotenbau, solange dieselben Autos fahren“ fängt den Verlust des Stufen-Caches nicht: ohne `car.levels[lod] = n` (`layers/vehicles.gd`) baut jeder Stufenwechsel neu und der alte Knoten bleibt – „leistung“ bleibt **grün**, weil im Messfenster genau 1 Auto eine neue Stufe erreicht und keines zurückwechselt. Die Regel selbst ist bewacht: Mit derselben Mutation wird `check_vehicles` **„instanzen“ rot** (`höchstens 577 Instanzen der gebauten Stufen (Budget 128) … FEHLT: höchstens 128 Instanzen nach jedem Bild`, `mutations/mut_leistung_cache_instanzen.log`, gemessen) – nur der beim Merge geänderte Fall „leistung“ behauptet mehr, als er prüft. | `mutations/mut_leistung_cache.log`: `34 Knotenbauten beim Erscheinen, 1 erste Stufen im Fenster`, OK (gemessen) | `bin/mutate.py <kopie> leistung_cache apply`, dann `check_vehicles.gd -- --only=leistung` | Im Fenster ein Auto gezielt zwischen zwei Stufen hin- und herschalten (Abstand setzen) und `vehicle_builds` vorher/nachher vergleichen: ein Wechsel zurück auf eine gebaute Stufe darf keinen Bau zählen. |
| M2S-04 | niedrig | Testläufer | `tests/run_tests.gd` (Unit-Läufer) mit `tests/unit/race3d/test_props.gd:506–507` | Bricht ein Test mit einem Skriptfehler ab, zählt der Läufer ihn als **bestanden**: Mit gebrochener Pylon-Nachtregel (`night_albedo` bzw. `emit_energy` der Kopie nicht gesetzt) meldet er „ok, 12 / 0“, obwohl `float(null)` mit `SCRIPT ERROR: Invalid call. Nonexistent 'float' constructor` abbricht. Rot wird es nur über den `SCRIPT ERROR`-grep von `run_tests.sh` – ein Einzellauf des Tests (wie beim Entwickeln üblich) zeigt grün. Das Tor selbst hält: `tools/run_tests.sh test_props` mit derselben Mutation meldet „12 Tests, 0 fehlgeschlagen ==> Godot meldet Skriptfehler (siehe oben) ==> Tests FEHLGESCHLAGEN“, Exit 1 (`mutations/props_gate.log`, gemessen) – rot wird es nur über den grep, nicht über den Test. | `mutations/mut_props_pylon_albedo.log`, `…_emit.log` (gemessen) | `bin/mutate.py <kopie> props_pylon_albedo apply`, dann `godot --headless -s res://tests/run_tests.gd -- test_props` | Im Läufer einen `Logger` anmelden (`OS.add_logger`, wie `check_instance_budget.gd`), der Skriptfehler je Test zählt: Fehler während `inst.call(n)` → FAIL mit der Fehlerzeile (ein Abbruch lässt `_failures` leer, darum heute „ok“). Im Test `get_shader_parameter(…)` erst auf `null` prüfen und mit Meldung scheitern. |
| M2S-05 | niedrig | Prüfabdeckung | `tests/unit/race3d/test_terrain_builder.gd` `test_far_ground_lies_below_the_water_of_a_bridge` (beim Merge in b341df8 umgestellt) | Der Test unterscheidet nicht mehr: Ohne den Wasserterm in `FarGround.target_height()` bleibt er grün, weil auf seiner synthetischen Strecke das Wasser (18,09 m) 11,6 m über der Scheibe der tiefsten Straße (6,44 m) liegt – die Scheibe ist mit und ohne Wasserterm 6,44 m; er prüft nur noch `lowest_water()`. Die Regel bewachen `test_far_ground_water` (3 von 4 rot) und `check_terrain_cover` K1. | `mutations/mut_farground_water_tb.log` / `…_fw.log`, `gd/qa_farground_nums.gd` (gemessen) | `bin/mutate.py <kopie> farground_water apply`, dann `run_tests.gd -- test_terrain_builder` | Brücke im Test tiefer legen (Wasser unter `lowest_road − 4`) oder direkt `target_height() ≤ lowest_water − 0,3` **und** `< lowest_road − 4` für einen Fall prüfen, in dem nur der Wasserterm entscheidet. |
| M2S-06 | niedrig | Messwerkzeug Klang | `tools/audio/modern/capture_mix.gd` (Echtzeit-Mitschnitt mit dem Dummy-Treiber) | Unter Last mischt der Dummy-Treiber langsamer als die Uhr: Die WAV ist kürzer als die Laufzeit, die Phasenfenster (nach Uhrzeit) liegen dann auf dem falschen Klang. Pegelplan-Messungen auf einer belasteten Maschine sind so unzuverlässig, ohne dass es auffällt. | WAV 67,2 s bei 75 s Uhr (10 % kurz) bei Last 13–20 (gemessen) | `capture_mix.gd` bei Last ≥ 10 laufen lassen und Dateilänge gegen Laufzeit vergleichen | Im Movie Maker laufen lassen (`--write-movie … --fixed-fps 60`) mit `editor/movie_writer/mix_rate=44100` (Vorgabe ist 48 kHz) – so in dieser Prüfung (`gd/qa_capture_mix.gd`); oder die Phasenzeiten aus der Zahl der aufgenommenen Abtastwerte statt aus der Uhr nehmen und eine Abweichung > 2 % als FEHLER melden. |
| M2S-07 | niedrig | Rückfall / Text | `scripts/race/race_session.gd` `_show_fallback_message()` (Z. 572–574; Grund in `gfx_fallback`) | Der Hinweis beim Rückfall auf Arcade nennt immer die **Grafik** („… lässt sich mit dieser Grafik nicht starten …“), auch wenn der Grund fehlende oder kaputte **Spieldateien** sind (`manifest`: Manifest fehlt, kaputtes JSON, eine Netzdatei fehlt). Der Spieler sucht dann den Fehler bei seiner Grafikkarte/seinen Treibern statt bei der Installation (z. B. unvollständiger Download, Steam „Dateien prüfen“). Der Rückfall selbst ist richtig. | `fallback/` – Log `Vorbereitung abgebrochen (manifest)` bzw. `Modus Modern nicht möglich (selftest:debug)`, im Bild derselbe Text (`rueckfall_manifest_fehlt_2s.png`, `rueckfall_modelldatei_fehlt_8s.png`; gemessen) | in einer Kopie `assets/models/manifest.json` entfernen, `--stage=kiel_hamburg --graphics=modern` starten | Den Text nach dem Grund wählen: für `manifest`/fehlende Dateien z. B. tr(„Der Modus „Modern“ lässt sich nicht starten, weil Spieldateien fehlen oder beschädigt sind. Das Spiel läuft im Modus „Arcade“ weiter.“), sonst der Text von §4.4.2; `check_seam.gd`/`check_session.gd` um den zweiten Text erweitern (Vertragsfrage V-3). |

## 1. Arcade-Identität (Regeln 1–3)

| Prüfung | Ergebnis | Beleg |
|---|---|---|
| Eingefrorene Dateien (Vertrag §2 Regel 1, alle 29 Pfade/Ordner) gegen `main` | **0 Dateien geändert**, keine fehlt, Arbeitsbaum sauber | `bin/frozen_diff.sh` → `frozen_diff.out` (gemessen) |
| `ERGEBNIS` von `run_stage.gd`: v0.7.0 (`git archive main`, eigener Import) gegen den Kopf mit `--graphics=arcade` | **identisch auf drei Etappen** (je 27 Schlüssel; der Kopf hat nur `gfx: "arcade"` dazu): Kiel – Hamburg ganz (12 Uhr, trocken, Seed 7, 95 km, 346,07 s), Bern – Mailand ab km 150 (22 Uhr, Schnee, Kompakt, Seed 3), Dortmund – Frankfurt ab km 170 (19:30, Regen, Gran Turismo, Seed 5) – andere Etappen als die Prüfung von M1 | `bin/ergebnis.sh` → `ergebnis/{ref,cur}_{kh,bm,df}.json` (gemessen) |
| Regel 3: dieselbe Etappe in Modern | Kiel – Hamburg: identisch bis auf `gfx: "modern"` | `ergebnis/curmodern_kh.json` (gemessen) |
| Arcade-Klang (Motor-Mischer je Auto mit Seed, `SfxSynth`, Verkehr, Busse mit Effekten, 40 eingefrorene Dateien) | Fingerabdruck aus v0.7.0 **selbst neu erzeugt** = eingecheckter Fingerabdruck = Kopf (172 Werte, ohne Bildschirm); `test_arcade_identity`, `check_modern_audio` (`arcade_after`: Mischer-SHA-256 wie v0.7.0) und `check_arcade_lean` im Testlauf grün | `audio_golden/{ref,cur}_headless.json` (gemessen) |
| Arcade-Bilder `tools/golden.sh check` | siehe Abschnitt 6 (einmal, zum Schluss) | |

## 2. Klang

Hier hört niemand zu: alles unten ist an Dateien **gemessen**; wie es klingt, ist **abgeleitet** bzw. Sache des Nutzers.

**Messweg.** Ein Echtzeit-Mitschnitt ohne Bildschirm (`capture_mix.gd`-Weg) lief unter der Last dieser VM (13–20 auf 4
Kernen) 10 % zu kurz: Die WAV war 67,2 s lang, die Uhr lief 75 s – der Dummy-Treiber mischt bei CPU-Mangel weniger
als Echtzeit, Zeiten im Protokoll und in der Datei laufen auseinander. Darum laufen alle Klangmessungen dieser Prüfung
im **Movie Maker** (`--write-movie`, `--fixed-fps 60`, `--audio-sync`): Der Klang wird im Gleichschritt mit den Bildern
gemischt, Protokoll und WAV haben eine Uhr, die Last kann nichts verschlucken. Damit der Movie Maker mit 44,1 kHz
mischt wie das Spiel (D26) und nicht mit seiner Vorgabe 48 kHz, liegt in der Prüfkopie eine `override.cfg`
(`editor/movie_writer/mix_rate=44100`). Bild: Arcade (Regel 4 – das Bild spielt für den Klang keine Rolle),
Klang: Modern, **Gesamtlautstärke 1,0**. Skripte: `gd/qa_race_sound.gd` (echte Rennszene mit Strecke, Verkehr und
`AudioFeed`; protokolliert Feed-Zustand, Einmalklänge, Ereignisse, Musik, Tempo je Bild), `bin/race_sound.sh`,
Auswertung `bin/race_sound_analyze.py` (BS.1770 und True Peak über `tools/audio/qc/qc_lib.py`).

**Kiel – Hamburg im echten Rennen** (Movie Maker, Gesamtlautstärke 1,0, Bild Arcade, Klang Modern; die Feed-Karte der
Etappe vorher aus `AudioFeed` berechnet: `gd/qa_feed_map.gd` → `sound/feed_map_kh.log`):

| Mitschnitt | was | True Peak / Lautheit | Befund (gemessen) |
|---|---|---|---|
| `rs_concrete` km 24,3 → 33,7, 0 → 174 km/h | Asphalt → **Betonplatten ab km 25,0** | −1,98 dBTP, −14,6 LUFS integriert | Belag wechselt bei km 25,02 genau wie in der Karte; auf Beton +7 dB 160–630 Hz-Rauschen gegen den Asphalt davor (andere Geschwindigkeit, vermischt), in der Hüllkurve eine Linie bei 14,1 Hz = 2 × v / 5 m bei 125,8 km/h (Plattenrhythmus); kein Aussetzer |
| `rs_koehlbrand` km 77,6 → 81,9 | **Köhlbrandbrücke**, Stahldeck km 78,0–80,61 | −4,54 dBTP, −16,3 LUFS | **4 Fugen** gespielt bei km 78,01 / 79,02 / 80,01 / 80,62 = Fugen der Strecke (78,0 / 79,0 / 80,0 / 80,61), jede als Spitze +5,2 … +10,3 dB über dem Median der Hüllkurve (±1 s); auf dem Deck +9 dB bei 630 Hz – 2,5 kHz, +7 dB bei 2,5 – 10 kHz gegen Asphalt; die zwei „Knack-Kandidaten“ des Detektors sind genau zwei dieser Fugen |
| `rs_cobbles` km 86,6 → Ziel 95,2 | **Hamburger Altstadt**: Pflaster und Asphalt im Wechsel | −1,55 dBTP, −15,4 LUFS | Wechsel genau an den Blöcken der Karte (87,01 P / 87,82 A / 88,71 P / 89,61 A / 90,51 P / 92,31 A / 94,11 P); bei gleichem Tempo (45–50 km/h) Pflaster gegen Asphalt **+3,6 … +4,6 dB bei 160–630 Hz und +5,8 … +7,6 dB bei 2,5–10 kHz** – deutlich im Spektrogramm; Etappe im Ziel (`stage_finish`) |
| `rs_crash` km 30, 220 km/h ohne Autopilot in die rechte Spur | Blitzer → Verfolgung (Martinshorn) → **schwerer Aufprall** bei 174 km/h → „busted“ | Aufprall-Fenster −4,56 dBTP, ganze Aufnahme −1,93 dBTP | Schichten `crunch`, `debris`, `hit_heavy`, `collision_heavy` (schwere Stufe); **≤ −1 dBTP bei Gesamtlautstärke 1,0 erfüllt** (A-14) |
| `rs_crash2` km 40, 240 km/h, mittlere Spur | zweiter schwerer Aufprall bei t 9,3 s | Fenster −4,06 dBTP, ganz −2,13 dBTP | wie oben; danach steht das Auto im Leerlauf (siehe Knack-Kandidaten unten) |
| `rs_arcade_koehlbrand` | dieselbe Fahrt mit Profil **Arcade** | −4,51 dBTP, −20,9 LUFS | keine Fugen, keine Feed-Ereignisse (Arcade hört nichts davon – unverändert); Modern bei gleicher Fahrt 4,6 LU lauter |

Spektrogramme mit Belagstreifen und Fugen-/Aufprallmarken: `klang_kiel_hamburg_spektrogramme.png`.

**Knacken.** Der allgemeine Detektor (Blocksprung > 4 × Umgebung) meldet in den Fahrten 1–4 Kandidaten je Mitschnitt;
jeder angesehen (`bin/click_inspect.py`, Wellenform ±15 ms): Fugen, ein Plattentransient, zwei tieffrequente Stöße
(Vorbeifahrt) – **kein Sprung im Signal** (Schritt ≤ 3,1 × p99 der Umgebung, Hüllkurve davor und danach gleich). Im
**Leerlauf nach einem Unfall** (Tempo 0) meldet er 19 bzw. 87 Kandidaten: Jeder Zündstoß trägt an seiner fallenden Flanke
einen 1,5-ms-Klingler über 8 kHz (`sound/rs_crash2_click_21.00.png`) – Textur des Motors, kein Sprung; die Prüfung von
M1 fand dasselbe im Arcade-Leerlauf. Ob man das als Ticken hört, ist abgeleitet bzw. Sache des Nutzers.

**Begrenzer und Stinger im echten Rennen** (Movie Maker, Gesamtlautstärke 1,0):

| Mitschnitt | Ergebnis (gemessen) |
|---|---|
| `rs_concrete` gegen `rs_concrete_nolim` (derselbe Lauf mit `audio.modern.limiter.enabled = false` über `user://game_config.json`) | Ohne Begrenzer True Peak −1,74 dBTP / Abtastspitze −1,77 dBFS; Absenkung durch den Begrenzer höchstens **0,86 dB** (beim Anfahren mit Vollgas, t 0,8 s), p95 0,25 dB, 5 von 600 50-ms-Blöcken über 0,5 dB – beim Reisen auf Beton greift er kaum (A-14). Die zwei Läufe sind nicht bitgleich (Median der Abweichung leiser Blöcke 0,09 dB): Zahlen ±0,1 dB |
| `rs_crash_music` – wie `rs_crash`, mit Rennstück | Stück „Linke Spur“ startet bei „LOS!“; „busted“ bei 15,13 s → **Stinger `linke_spur_polizei` bei 15,50 s** (nächster Schlag); True Peak gesamt −1,83 dBTP (Musik + schwerer Aufprall) |
| `rs_fuel_music` – `--fuel=0.004`, mit Rennstück | `out_of_fuel` bei 7,52 s → **Stinger `linke_spur_tank` bei 7,78 s**; Abschleppen bei 14,53 s |

**Pegelplan, Ducking, „Musik im Rennen“, Menüs** (`gd/qa_capture_mix.gd` = `tools/audio/modern/capture_mix.gd` mit
Movie-Maker-Uhr und `--race-music=0`; Standardregler, Gesamtlautstärke 0,8; Gran Turismo; `measure_mix.py`):

| Phase | Auto allein („Musik im Rennen: Aus“) | Musik allein (Auto stumm, Ducking folgt der Fahrt) | beides | Plan (D29) |
|---|---|---|---|---|
| Leerlauf | −23,96 LUFS | −18,43 | −17,13 | Auto −24, Musik −19,5 |
| Vollgas | −15,78 (Kurzzeit-Median −15,60, max −14,85) | −23,71 | −15,24 | Auto −16 ± 1,5, Musik 8 dB darunter (−24) |
| Vollgas am Anschlag | −14,42 | −23,70 | −14,11 | |
| Reisen 130 km/h | −21,47 | −21,47 | −18,74 | Auto −21 |
| Menü | Modern −21,2 integriert, Kurzzeit-Median −20,1 | | | −20 |
| Menü Arcade (v0.7.0-Titel, unverändert) | −29,5 | | | – |

Musik bei Vollgas **7,9 dB unter dem Auto** (Plan 8), Ducking Leerlauf → Vollgas 5,3 dB, „Aus“ = keine Musik im Rennen.
Beim Reisen mit 130 km/h ist die Musik so laut wie das Auto (0 dB darunter) – so gebaut (Ducking nach dem Fahrzustand),
ob das gefällt, entscheidet der Nutzer (abgeleitet).

**Musik über den echten Spielablauf** (`gd/qa_music_flow.gd` nach `tests/race/run_race.gd`: echter `GameFlow`, Rennen
Kiel – Nürnberg, Autopilot mit Countdown, kopflos mit spielenden Playern, Zeitraffer 6; jede Änderung des
`MusicDirector`-Zustands protokolliert, `bin/music_parse.py`):

| Lauf | Ergebnis (gemessen) |
|---|---|
| „Musik im Rennen: An“, 4 Etappen (512 s) | Etappenbildschirm: **Zwischenspiel**; Etappe 1 **Linke Spur** (#1), 2 **Nachtfahrt** (#2), 3 **Rückenwind** (#3), 4 wieder **Linke Spur** (#4) – Rotation 1 → 2 → 3 → 1; jedes Stück setzt mit „LOS!“ ein; im Ziel Schluss „normal“ und bei den Etappen 1–3 der Ziel-Stich (`*_ziel`), bei 4 der Schluss ohne Stich (Taktgrenze näher als `ZIEL_MIN_S`, so gebaut); Ergebnisbildschirm: das Stück klingt aus, das Zwischenspiel blendet in 0,6 s ein und läuft über Routenwahl und Etappenbildschirm ohne Neustart weiter. „rekord“ kam nicht vor, weil die Bestenlisten vorbelegte Zeiten haben, die der Autopilot nicht schlägt |
| „Musik im Rennen: Aus“, 2 Etappen (296 s) | in der Etappe **keine** Musik; im Ziel der Schluss des Stücks der Rotation als Ziel-Klang (`linke_spur_schluss`, dann `nachtfahrt_schluss` – so dokumentiert); Zwischenspiel zwischen den Etappen wie mit „An“ |
| Stinger in der Etappe (oben) | `busted` → `linke_spur_polizei`, `out_of_fuel` → `linke_spur_tank`, jeweils auf dem nächsten Schlag |

Keine Fehler- oder „leaked“-Zeile in allen Klangläufen (17 Prozesse).

**Wind, Reifen und Menüklänge einzeln** (15.11., Nachtrag zu Punkt 2 der vorigen Fassung; `gd/qa_tyre_wind.gd` =
`capture_mix.gd` mit Movie-Maker-Uhr und drei Szenarien, Profil Modern, Standardregler, Gran Turismo, die übrigen
Busse über `--mute-bus` stumm; `bin/tyre_wind.sh`, Auswertung `measure_mix.py` und `bin/analyze_tw.py` →
`tyrewind/analyze.txt`; alle Zahlen gemessen):

| Mitschnitt | Ergebnis |
|---|---|
| Wind allein (`MWind`; Motor, Fahrbahn, Musik stumm), je 4 s gehalten | 0 km/h still (−140 LUFS); 50 km/h −63,2; 100 −44,3; 150 −35,3; 200 −29,3; 240 km/h −24,6 LUFS. Stetig steigend, 100 → 200 km/h +15,0 dB (Gesetz 55 dB je Dekade = +16,6 dB für das Grundband; das Wummern setzt erst nahe am Höchsttempo ein); hochgerechnet auf 270 km/h (Höchsttempo GT) ≈ −21,8 LUFS bei Gesamtlautstärke 0,8 – passt zur Regel „Wind 3 dB unter dem Motor bei Höchsttempo“ (`test_road_audio`; abgeleitet, ±1 dB) |
| Reifen (`MRoad`; Motor, Wind, Musik stumm), 120 km/h Asphalt | Rollen −32,1 LUFS; Quietschen voll (`set_skid 1`) **−18,3 LUFS** (+13,8 dB, Schwerpunkt 630 Hz – 2,5 kHz +15 dB); nach dem Loslassen sofort wieder −32,1 (kein Hängenbleiben); halbes Quietschen (0,4) −26,8; True Peak höchstens −8,9 dBTP |
| Menü- und Ansageklänge einzeln (1 s Abstand, ohne Musik) | `ui_move` −27,8, `ui_ok` −25,2, `ui_back` −24,6, `ui/ui_tab` −25,7, `ui/ui_toggle` −26,2, `ui/ui_error` −24,6, `beep` −17,2, `go` −13,0, `finish` −9,9 LUFS (Kurzzeit, Gesamtlautstärke 0,8); jeder setzt weich ein (erster Schritt ≤ −42 dB) und klingt ohne Sprung aus; `ui_error.wav` blendet in ≈ 10 ms von −24 dBFS auf Stille (kurz, aber kein Sprung – ob man es hört, abgeleitet); `audio_qc.py` meldet alle Dateien OK |

Keine Fehler- oder „leaked“-Zeile in den drei Läufen.

## 3. Modell-Pipeline

| Prüfung | Ergebnis | Beleg |
|---|---|---|
| Manifest neu erzeugt (`export_models.py --manifest-only`, in der Kopie) | **byte-gleich** mit dem eingecheckten (auch `sets_default.json`); 87 Modelle, 183 Sets (105 mit Modell, 78 Platzhalter) | `models/manifest_only.log`, `md5sum -c` (gemessen) |
| Manifest gegen die Modellordner | 87 Modelle = 87 Ordner mit `model.json`; 490 genannte Netz-/Texturdateien alle vorhanden, jede Textur mit `.import`; **keine** Datei in den Ordnern, die das Manifest nicht nennt; kein Set nennt ein fehlendes Modell, keine Variante ein fehlendes | `bin/models_cheap.sh` → `models_cheap.out` (gemessen) |
| `validate_models.py --report` | **OK** – Netze 18,08 MB von 40 MB, Texturen 38,20 MB Grafikspeicher von 240 MB, Quellen 26,58 MB von 60 MB | `models/validate.log` (gemessen) |
| Export-Determinismus (`bin/export_det.sh`, in der Prüfkopie) | 5 Modelle über alle M2-Materialwege mit `--force --jobs=1` aus den Generatoren neu exportiert und gebacken: `traffic/truck` (Rückstrahler-Kanal 15, 3,3 s), `police/de` (7,5 s), `props/tree_olive_b` (Samenvariante mit geteiltem Blattatlas, 11,2 s), `props/bridge_pylon` (Cycles-Atlas, 138,9 s), `props/church` (Haus-Bauer, Atlas mit Nachtfenstern, 424,0 s) – **alle Dateien byte-gleich mit den eingecheckten**; ein **zweites Backen byte-gleich** mit dem ersten | `exportdet/export.log`, `bake_1.log`, `bake_2.log` (gemessen) |
| `export_models.py --check-keys` | **OK** – „87 Modelle: ein geänderter Lack, Metallwert, Blickwinkel oder eine Markierung im Sprite-Katalog ergibt für genau die betroffenen Modelle einen neuen Schlüssel“ (≈ 20 min unter Last) | `q_export_det.log` (gemessen) |
| `check_sprite_geometry.py --jobs 2` (Sprites unverändert gegen das Fixture aus v0.7.0) | **OK**: 187 Sprite-Sets gebaut (1 185 s), 187 identisch – davon 1 nur mit anderer Flächenreihenfolge (`landmarks/fernsehturm_berlin`, Blenders UV-Kugel, bekannt), 0 verändert, 0 fehlend | `exportdet/sprite_geometry.log` (gemessen) |

## 4. Wachen die beim Zusammenführen geänderten Tests noch ihre Regel? (Mutationen)

Je Regel genau **eine Zeile Produktcode** in der Prüfkopie `m1/QA-M2-SYSTEM/mut` (`git archive` des Kopfes, nie im
Gate-Arbeitsbaum) gebrochen (`bin/mutate.py`), der wachende Test gestartet, die Zeile aus dem Arbeitsbaum
zurückgeholt (`bin/mutations.sh`, Logs `mutations/`). Vorher lief jeder dieser Tests auf der unveränderten Kopie
grün (Grundlinie).

| Regel (Test) | gebrochene Zeile | Ergebnis |
|---|---|---|
| Set ohne Modell als Ersatz gezeigt (`check_vehicles` „kasten“, Test-Manifest) | `layers/vehicles.gd` `_set_level`: Kasten-Ersatz `n = null` | **rot** (`police/at` nicht als Kasten gezeigt) |
| dto. | `_update_car`: Bild-Ersatz statt `_update_sprite(…)` nur `_show(car, false)` | **rot** (`traffic/sports_red` nicht gezeigt) – kopflos läuft auch der Bild-Weg |
| keine Stufe fürs Instanzbudget freigegeben (`leistung`) | `INSTANCE_BUDGET := 8` | **rot** |
| kein Knotenbau, solange dieselben Autos fahren (`leistung`) | `car.levels[lod] = n` entfernt (gebaute Stufen werden nicht behalten, jeder Stufenwechsel baut neu, der alte Knoten bleibt hängen) | **grün – nicht erkannt**: im Messfenster erreicht genau 1 Auto eine neue Stufe, keines wechselt zurück (`34 Knotenbauten beim Erscheinen, 1 erste Stufen im Fenster`) |
| Brückenpylon-Modell nachts dunkel (`test_props` … `is_a_model_with_its_aviation_light`) | `dup.set_shader_parameter("night_albedo", …)` entfernt | Läufer meldet **„ok“, 12 / 0** – der Test bricht mit `SCRIPT ERROR: Invalid call. Nonexistent 'float' constructor` (`test_props.gd:507`, `float(null)`) ab, ohne zu scheitern; rot nur über den `SCRIPT ERROR`-grep von `run_tests.sh` |
| dto. | `dup.set_shader_parameter("emit_energy", 0.0)` entfernt | dto. (`test_props.gd:506`) |
| Wahrzeichen ohne Sprite/Modell mit Ersatz-Set (alle 20 Anfahrten) | `landmark_fallbacks()`: Bedingung nie wahr | **rot** (`test_procedural_landmarks_…_get_their_fallback`) |
| Flugbefeuerung blinkt wie Arcade | `blink_lit`: Phase mit falschem Vorzeichen | **rot** (`test_pylon_beacon_blinks_like_arcade`) |
| Pylon-Vertretung ohne Lichtebene (Test-Manifest ohne Pylon-Modell) | `dark_material`: `lights_rect` nicht genullt | **rot** (`test_procedural_bridge_pylon_stand_in_stays_dark_at_night`) |
| Fernboden unter dem tiefsten Wasser (eine Regel, FIX-WASSER) | `target_height()`: nur noch `lowest_road − drop` | `test_far_ground_water` **rot** (3 von 4); `test_terrain_builder` … `below_the_water_of_a_bridge` (beim Merge umgestellt) **grün – erkennt es nicht**: auf seiner synthetischen Strecke liegt das Wasser (18,09 m) 11,6 m **über** der Scheibe der tiefsten Straße (6,44 m) – die Scheibe ist mit und ohne Wasserterm 6,44 m (gemessen, `gd/qa_farground_nums.gd`); der Test prüft nur noch `lowest_water()` |
| dto., Nachlauf (15.11.): fängt `check_vehicles` „instanzen“ es? | dieselbe Zeile | **rot**: höchstens 577 Instanzen der gebauten Stufen bei Budget 128 (`mutations/mut_leistung_cache_instanzen.log`) – die Regel ist bewacht, nur nicht vom Fall „leistung“ (M2S-03) |
| Pylon-Nachtregel durch das Tor (Nachlauf) | `night_albedo` nicht gesetzt, dann `tools/run_tests.sh test_props` | **Tor rot** („12 Tests, 0 fehlgeschlagen ==> Godot meldet Skriptfehler ==> Tests FEHLGESCHLAGEN“, Exit 1) – über den grep, nicht über den Test (M2S-04) |
| Modern-Änderungsmelder (beim Merge neu erzeugt) | `road.gd`: `lane_line_w` × 1,2 (Spurlinien 20 % breiter; die erste Mutation am Shader-Vorgabewert war wirkungslos, weil `road.gd` den Wert zur Laufzeit setzt) | **rot**: `modern_s3_hoch_00.png: ANDERS`, „GOLDEN modern: 0 von 1 identisch (Teilmenge s3)“, 504 s (`mutations/golden_lane.log`) |

Nach jedem Nachlauf ist die Kopie wieder gleich dem Arbeitsbaum (`vehicles.gd`, `props.gd`, `road.gd` = Arbeitsbaum, `q_followup.log`).

## 5. Robustheit

**Rückfall auf Arcade** (`bin/fallback.sh`: echtes Spiel über `GameFlow -- --stage=kiel_hamburg --graphics=modern`,
Xvfb 1280 × 720, Bilder 2 s und 8 s nach dem Start; Manifest und Netzdatei nur in der Prüfkopie verändert und danach
wiederhergestellt, `= Arbeitsbaum` geprüft):

| Fall | Ergebnis (gemessen) |
|---|---|
| `--gfx-debug=fail` | Etappe läuft in **Arcade**, Hinweis im Bild, Log `Modus Modern nicht möglich (selftest:debug)`, kein Startmarker zurückgelassen, Exit 0 |
| `assets/models/manifest.json` fehlt | Arcade, `Vorbereitung abgebrochen (manifest)`, Hinweis im Bild (`rueckfall_manifest_fehlt_2s.png`), kein Marker |
| Manifest abgeschnitten (kaputtes JSON) | `Parse JSON failed … Unterminated string` (eine Fehlerzeile der Engine), dann derselbe Rückfall `manifest` |
| eine Netzdatei des Spielerautos fehlt (`player/limousine/lod0_body.res`) | `Vorbereitung abgebrochen (manifest)`, Arcade, Hinweis (`rueckfall_modelldatei_fehlt_8s.png`) |

Der Hinweis lautet in allen Fällen wörtlich wie §4.4.2: „Der Modus „Modern“ lässt sich mit dieser Grafik nicht
starten. Das Spiel läuft im Modus „Arcade“ weiter.“ – auch wenn nicht die Grafik, sondern Spieldateien fehlen
(Vertragsfrage V-3).

**Leistungstest** (`--bench=all`, Xvfb, llvmpipe auf 4 Kernen bei Last 22, `bin/bench.sh`): Exit 0 nach 191 s;
`user://leistungstest.json` geschrieben und gleich `--bench-out`; `bin/bench_check.py`: **FORMAT OK** (alle Pflichtfelder,
drei Szenen). Gemessen: Autobahn bei Tag 3,1 fps (1 %-Tief 1,1; p95 648 ms; Skript 3,49 ms; 132 Aufrufe; 109 864
Dreiecke; Vorbereitung 65 s kalt), Stadt bei Nacht im Regen 1,5 fps (Skript 5,56 ms; 81 Aufrufe), Bergstrecke mit Tunnel
3,4 fps (Skript 3,04 ms; 69 Aufrufe); Urteil `too_slow`, Vorschlag **Arcade** – richtig für Software-Grafik. Mit
`--gfx-debug=fail`: Exit 1 (dokumentiert), Datei mit `fallback: selftest:debug`, 0 Szenen, Vorschlag Arcade.

**Fenster schließen.** `WM_DELETE_WINDOW` (per `XSendEvent`, ohne Fenstermanager, `bin/xclose.py`) nimmt Godot auf
dem nackten Xvfb nicht an (`WM_PROTOCOLS` des Fensters ohne `WM_DELETE_WINDOW`) – in v0.7.0 genauso (M1). Alle
Beenden-Fälle unten laufen darum über **SIGTERM** (wie Steams „Spiel beenden“); das Schließen über das Menü prüft
`check_quit_sound` (3 Starts, kein „leaked“, Abschnitt 6).

**Beenden und Neustart in jedem Bildschirm** (`bin/quit_screens.sh`: echtes Spiel auf eigenem Xvfb 1280 × 720, gespeicherter
Modus Modern, Klang Modern; jeder Bildschirm mit `--screen=<name>` und Beispieldaten, nach 14 s Bild, dann Beenden über
SIGTERM, danach Neustart **ohne** Argumente, nach 14 s Bild, wieder SIGTERM; Bilder alle angesehen):

| Fall | Ergebnis (gemessen) |
|---|---|
| 14 Bildschirme: Titel, Rennen wählen, Fahrzeug (Showroom in Modern), Startzeit, Route wählen, Etappe, Etappe beendet, Rennen beendet, Einzelne Etappe, Bestenlisten, Optionen, Fähre, Grafik wählen, Leistungstest | jeder Bildschirm zeigt seinen Inhalt (`beenden_14_bildschirme.png`); SIGTERM beendet sofort (Exit 143), **kein Startmarker**, `settings.json` unverändert (`graphics_mode: modern`, `gfx_preset: medium`), Neustart zeigt den **Titel ohne Absturzfrage**; 0 Fehler-/Warnzeilen in 28 Logs |
| Modern-Etappe Kiel – Hamburg, SIGTERM **beim Laden** (5 s) | Marker bleibt (wie ein Absturz – so gebaut, FIX1); Neustart: Titel mit der **Absturzfrage** („Der Modus „Modern“ wurde beim letzten Start nicht richtig beendet.“, „Bei Arcade bleiben“ fokussiert; `beenden_absturzfrage_nach_sigterm_beim_laden.png`), dieser Start läuft Arcade |
| Strike 1: Antwort mit Return („Bei Arcade bleiben“) | `settings.json` bleibt **modern**, `modern_start.strikes` = 1, Marker weg – wie FIX1 („der erste Abbruch behält die Wahl“) |
| Modern-Etappe, SIGTERM **nachdem Modern zeichnet** (zweiter Lauf 15.11., `bin/quit_stage2.sh`: Warten nach Zustand statt fester 45 s – im ersten Lauf lud die Etappe bei Last 26 noch) | Marker nach 8 s gesetzt und nach weiteren 62 s entfernt (2 s gezeichnete Modern-Bilder), 8 s später SIGTERM: Exit 143, **kein Marker, keine Strikes**, `settings.json` unverändert Modern/Mittel; Neustart zeigt den **Titel ohne Absturzfrage**. Bei der Last war die Etappe zu diesem Zeitpunkt noch im Countdown („1“, Auto am Start) – das eigentliche Fahren deckt der 20-min-Lauf unten ab |
| dto. im **Pausenmenü** (Escape, dann SIGTERM) | Pausenmenü im Bild (Weiterfahren / Etappe neu starten / Aufgeben), SIGTERM Exit 143, kein Marker; Neustart: Titel ohne Frage, Einstellungen Modern |
| Strike 2: SIGTERM **beim Laden** zum zweiten Mal (Strikes vorher 1) | Marker bleibt; Neustart: Frage mit dem Text „Das ist schon zum zweiten Mal passiert. „Bei Arcade bleiben“ stellt die Grafik auf „Arcade“ um …“, „Bei Arcade bleiben“ fokussiert; Return speichert **`graphics_mode: arcade`**, Marker und Strike-Datei weg; der nächste Start zeigt den Titel ohne Frage – wie FIX1 („nach dem zweiten Abbruch Arcade“) |

Bilder angesehen: `beenden_modern_etappe.jpg` (Fahrt/Countdown, Pause, beide Neustarts, Frage, Antwort, nächster Start); 0 Fehler-/„leaked“-Zeilen in den 7 Logs (gemessen).

**20 Minuten Modern** (`bin/soak.sh`: `tests/race/run_race.gd -- --race=kiel_nuernberg --autopilot --graphics=modern
--sound=modern --gfx-preset=medium --timescale=1 --max-seconds=1200` unter Xvfb 1280 × 720, llvmpipe, Last 23–26):
1 212 s Wanduhr, am Ende im Zustand `racing` (Etappe Kiel – Hamburg läuft; das Ende kommt von meinem Zeitlimit, nicht
vom Spiel). **0 Fehler-, Warn- oder „leaked“-Zeilen** (außer der V-Sync-Warnung von llvmpipe). Speicher des
Godot-Prozesses (eigene Abtastung alle 30 s, `soak/rss_godot.tsv`): 1,583 GB nach 2,5 min, 1,657 GB nach 4,5 min, danach
**flach 1,659–1,660 GB** bis zum Ende; 23 Threads und 8 offene Dateien durchgehend gleich – kein Wachstum (gemessen).
Wie weit das Auto kam, protokolliert `run_race.gd` nicht (nur Etappenenden); bei 1–3 Bildern/s auf Software-Grafik
läuft die Simulation langsamer als Echtzeit (abgeleitet). Hinweis: Die RSS-Spalte im eigenen Log `q_soak.log` misst
den `timeout`-Prozess (Fehler in meinem Skript, `pgrep` ohne Filter) – gültig ist `rss_godot.tsv`.

**Builds und Größen** (`bin/builds.sh` im Gate-Arbeitsbaum; `build/` ist ignoriert, der Arbeitsbaum blieb sauber):

| Build | Ergebnis (gemessen) |
|---|---|
| Linux `tools/build_linux.sh` | Exit 0, 94 s; `CrossingEurope.x86_64` 496,5 MB, 1 574 Dateien im PCK; `pck_report.py`: Summe im Archiv **184,7 MB** von 277 MB Budget, kein Teil über seinem Budget (Arcade-Sprites 71,07 / 71,0 und Arcade-Klang 14,72 / 14,7 liegen in der Toleranz × 1,02 für unveränderte Teile); Modern: Modelle 18,73 / 40, Texturen 13,04 / 60, Klang 16,38 / 23, Musik 18,60 / 25 MB |
| Windows `tools/build_windows.sh` | Exit 0, 190 s; `CrossingEurope.exe` 532,3 MB (Versionsfelder 0.7.0.0, PE-Prüfsumme stimmt), **Zip 194,5 MB gemessen** (Warnung erst über 300, Abbruch über 330 MB; Vorgabe „Download höchstens ≈ 280 MB“ erfüllt) |
| Smoke Linux `tools/smoke_modern.sh build/CrossingEurope.x86_64` | **OK**: Arcade (29 s) und Modern (304 s bei Last 24) fahren Kiel – Hamburg (Bilder 6 s/14 s nach dem Start angesehen: Auto, Strecke, HUD, Tipps), Leistungstest im Build: Autobahn 2,2 fps, Vorschlag Arcade/Niedrig; 0 Fehlerzeilen |
| Smoke Windows unter Wine `tools/smoke_modern.sh build/CrossingEurope.exe` (eigenes Wine-Präfix) | **OK**: wineboot 49 s; Arcade (49 s) und Modern (338 s bei Last 24) fahren Kiel – Hamburg – im Bild 10,97 s nach „LOS!“ derselbe Simulationsstand in beiden Modi (km 2,9, 168 km/h, Tipp, Tankanzeige; `wine_arcade_modern.png`, angesehen), Leistungstest im Build: Autobahn 3,2 fps, p95 496 ms, Vorschlag Arcade/Niedrig; im Modern-Log nur die Wine-Warnung „Failed to get SDR white level“, keine Fehlerzeile |

Die Builds tragen die Version **0.7.0** (Datei- und Produktversion der `.exe` 0.7.0.0, `game_version` in `leistungstest.json`,
„v0.7.0“ im Titel): so vorgesehen – `project.godot` wird erst bei REL angehoben, und ein Testbuild für den Nutzer läuft
über `tools/build_testbuild.sh <version> <name> <Nutzerordner>`, das Version, Nutzerordner und Dateinamen nur für den
Export setzt (Vertrag §11). Kein Befund; für den nächsten Testbuild dieses Werkzeug nehmen, nicht `build_linux.sh`/`build_windows.sh`.

## 6. Tore auf dem Kopf `6e48405` (gemessen; Last der VM 13–33 durch die anderen Pakete)

| Tor | Aufruf | Ergebnis |
|---|---|---|
| Import / Skripte | `godot --headless --path . --import`; `check_scripts.gd` (in `run_tests.sh`) | Exit 0; 310 Skripte, 0 fehlerhaft |
| Kopflose Tests | `tools/run_tests.sh` (einmal voll, 15:07–15:26) | **„Tests bestanden“, Exit 0, 1 133 s**: 749 Unit-Tests / 0 fehlgeschlagen, 175 CHECK-Zeilen OK, 0 FEHLER; Fairness F1 0 Fälle bis 270 m (Spuren 260 m), F2 ≤ 0,593 / 0,596 / 0,555, F3 0 von 874, F7 0 von 207 166; Pfad 267,6 m / Schleifen ab 2 064 m. Das Ziel ≤ 12 min (A-6) ist unter dieser Last überschritten (M2ZS1: 881 s; V-4) |
| Render-Prüfungen Arcade | `tools/run_render_checks.sh arcade` | **2 / 2 OK**: `check_glow_occlusion` 16/16, `check_sprite_flip` |
| Render-Prüfungen Modern | `tools/run_render_checks.sh modern` (Lauf 1 ganz; nach dem Zeitlimit die übrigen Dateien einzeln, nice 10) | **17 von 17 Dateien OK** (eine erst mit erhöhtem Zeitlimit): `facade_render`, `instance_budget` (ganze Szene ≤ 142 Instanz-Uniforms, Grenze 230), `light_base` (Schatten −0,10 %), `models`, `modern_render` (Helligkeit 10/10, × 0,90–0,99), `occlusion`, `props_render`, `quit_sound` (3 Starts, kein „leaked“), `road_parity`, `seam_render`, `session_modern`, `showroom_render`, `start_km0` (Kanten ± 1 px, Kamera ≤ 1,14 px), `terrain_cover` (T1–T4, S1, C1, K1: 0,000 % Magenta), `vehicle_lights`, `vehicle_standin` (leer bestanden, M2S-02). `instance_budget_wald`: in den Läufen 1–2 unter Last kein Ergebnis (Exit 124 nach 900 s; Wiederholung nach 21 min abgebrochen, M2S-01); **Lauf 3 (15.11., allein von mir, `RENDER_CHECK_TIMEOUT=3000`, Last 20–33): OK nach 2 945 s** – „keine Ablehnung der Engine, Fahrzeug-Ebene höchstens 127 Instanzen (Budget 128, 6 freigegeben, 52 Bauten), ganze Szene höchstens 142 mit Instanz-Uniforms (Grenze 230)“, 1 033 Bilder (`q_wald.log`). Die Produktregel hält damit; mit dem Standard-Zeitlimit von 900 s wäre das Tor aber rot gewesen (M2S-01). **Damit 17 von 17 Modern-Dateien OK** |
| Arcade-Bilder | `tools/golden.sh check` (einmal, zum Schluss) | **20 von 20 identisch** (Arcade, 365 s) und **17 von 17 identisch** (Arcade-UI, 358 s) – einmal, als letztes Tor auf dem unveränderten Kopf (13.11., 05:26–05:39 UTC, Last 1,5; `q_golden.log`) |
| Modern-Änderungsmelder | `KEEP=… tools/golden.sh modern-check` | **6 von 6 identisch** (Start, S2, S3, S4, S5, S1 Nacht; 1 905 s) und OpenGL ES gegen OpenGL bei S3: OK, höchstens 2/255, PSNR 73,2 dB (467 s) – 15.11., Last 15–20 (`q_modern_check.log`; Startbild angesehen: Auto im Countdown hinter dem Starttor, wie Arcades Startstand). Mutation `lane_line_w` × 1,2 macht ihn rot (Abschnitt 4) |

## Vertragsfragen

| ID | Frage | Anlass |
|---|---|---|
| V-1 | Was ist ein Zeitlimit im Tor? `run_render_checks.sh` wertet Exit 124 (900 s je Datei) als FEHLER der Regel; nach A-11 ist eine Prüfung, die nur unter Last scheitert, kaputt. Vorschlag: Zeitlimit = eigener Zustand „kein Ergebnis“, Tor rot mit diesem Grund, Laufzeit je Datei im Protokoll; Dateien, die bei Last 20 über 5 min brauchen, gelten als zu reparieren. | M2S-01 |
| V-2 | Muss der Unit-Läufer (`tests/run_tests.gd`) einen Test, der mit einem Skriptfehler abbricht, selbst als FAIL zählen? Heute macht erst der grep von `run_tests.sh` das Tor rot; ein Einzellauf zeigt „ok“. | M2S-04 |
| V-3 | §4.4.2 nennt **einen** Hinweistext („… lässt sich mit dieser Grafik nicht starten …“). Er erscheint auch, wenn Spieldateien fehlen oder kaputt sind (Manifest, Netzdatei) – dann führt „Grafik“ den Spieler in die Irre. Zweiter Text für die Gründe `manifest`/Dateien (z. B. „… weil Spieldateien fehlen – bitte die Dateien des Spiels prüfen“)? | Rückfall-Fälle 2–4 |
| V-4 | A-6 „`run_tests.sh` ≤ 12 min“ ist ohne Maschine/Last nicht prüfbar: hier 1 133 s bei Last 13–18 (M2ZS1: 881 s). Ziel an eine unbelastete VM mit 4 Kernen binden oder als CPU-Zeit fassen? | Abschnitt 6 |
| V-5 | Klangmessungen auf belasteten Maschinen: Movie Maker (Bild-Uhr) als vorgeschriebener Messweg für `capture_mix`/Pegelplan, mit `editor/movie_writer/mix_rate=44100` (Godots Vorgabe 48 kHz ≠ D26)? | M2S-06 |
| V-6 | Pegelplan D29 nennt für die Musik nur „8 dB unter dem Auto bei Vollgas“. Beim Reisen mit 130 km/h ist sie gemessen **so laut wie das Auto** (−21,47 LUFS beide). Ist das gewollt (Ducking nach Fahrzustand) oder soll die Musik auch beim Reisen unter dem Auto bleiben? Entscheidet der Nutzer. | Abschnitt 2 |

## Geprüft und in Ordnung (Kurzliste, alles gemessen)

- Eingefrorene Arcade-Dateien (Regel 1): 0 Änderungen gegen `main`.
- `ERGEBNIS` Arcade = v0.7.0 auf drei Etappen (Kiel – Hamburg ganz; Bern – Mailand Schnee/Nacht; Dortmund – Frankfurt Regen/Dämmerung); Modern = Arcade bis auf `gfx`.
- Arcade-Klang: Fingerabdruck aus v0.7.0 neu erzeugt = eingecheckt = Kopf.
- `tools/run_tests.sh`: bestanden (749/0 Unit-Tests, 175 CHECK-Zeilen OK, 0 FEHLER; Fairness F1–F3/F7, Pfad).
- `audio_qc.py` über alle Ordner: 98 Klänge, 0 Fehler, Nähte, Pegel, True Peak, Manifest = Datei, Budgets (19,0/23 MB, 18,5/25 MB).
- Modell-Manifest: neu erzeugt byte-gleich; 87 Modelle = 87 Ordner; 490 Dateien da; keine Waisen; Validator OK.
- Kiel – Hamburg im Spiel (Movie Maker, Modern-Klang): Betonplatten ab km 25 hörbar im Takt, Köhlbrandbrücke mit 4 Fugen genau an den Fugen der Strecke, Hamburger Altstadt im Wechsel Pflaster/Asphalt genau nach den Blöcken, kein Aussetzer, kein Übersteuern, schwerer Unfall ≤ −4 dBTP bei Gesamtlautstärke 1,0.
- `tools/golden.sh check`: Arcade 20/20 und Arcade-UI 17/17 identisch; `modern-check` 6/6 und OpenGL ES gegen OpenGL OK (2/255).
- Render-Prüfungen: 2/2 Arcade, 17/17 Modern (die Waldprüfung erst mit erhöhtem Zeitlimit, M2S-01): kein Shader-Puffer-Überlauf im Wald bei „Hoch“ (≤ 142 von 230).
- Begrenzer: schwerer Unfall ≤ −4,1 dBTP bei Gesamtlautstärke 1,0; beim Reisen greift er höchstens 0,25 dB (p95).
- Musik: Rotation 1 → 2 → 3 → 1, Stinger (Polizei, Tank), Zwischenspiel, Ziel-Stich, „Musik im Rennen: Aus“; Pegelplan bis auf V-6 eingehalten.
- Wind (stetig mit dem Tempo), Reifenquietschen (+13,8 dB, kein Hängenbleiben), neun Menü-/Ansageklänge ohne Sprung.
- Modell-Pipeline: Export und zweites Backen byte-gleich, `--check-keys` OK, Sprites 187/187 unverändert, Validator und Budgets OK.
- Rückfall auf Arcade (`--gfx-debug=fail`, Manifest fehlt/kaputt, Netzdatei fehlt), Leistungstest-JSON, Beenden/Neustart in 14 Bildschirmen und der Modern-Etappe (Laden, Zeichnen, Pause, Strike 1 und 2), 20 min Modern ohne Fehler bei flachem Speicher, Linux- und Windows-Build (Wine) Arcade und Modern.

## Für die Nächsten (offen oder nur abgeleitet)

1. **Waldprüfung** (`check_instance_budget_wald`): bis M2S-01 repariert ist, nur mit `RENDER_CHECK_TIMEOUT=3600` und allein laufen lassen (hier 2 945 s bei Last 20–33).
2. Klang: der Schluss „rekord“ und „finale“ kam im Ablauf nicht vor (die Bestenlisten sind vorbelegt) – für den Test ein leeres `user://` mit leeren Bestenlisten nehmen. Reifen, Wind und Menüklänge sind seit dem Nachtrag einzeln gemessen (Abschnitt 2), im echten Rennen nur über die Feed-Karte.
3. Ob die Leerlauf-Textur nach einem Unfall (1,5-ms-Klingler an jedem Zündstoß) als Ticken hörbar ist, kann nur ein Mensch hören (`sound/rs_crash2.wav` ab 13 s).
4. Messweg Klang: Movie Maker mit Bild-Uhr und `override.cfg` (`editor/movie_writer/mix_rate=44100`), sonst laufen WAV und Uhr unter Last auseinander.
5. `tools/*.sh`, die sich selbst `nice -n 10` geben, nicht noch einmal in `nice` packen – die Werte addieren sich zu 19, dann verhungert die Prüfung neben anderen Agenten (so lief die Waldprüfung in Lauf 1).
6. Mutationen an Shader-Uniforms, die zur Laufzeit gesetzt werden (`lane_line_w` in `road.gd`), im Setter brechen, nicht im Shader-Vorgabewert – sonst ist die Mutation wirkungslos (so mein erster `golden_road`-Versuch).
7. Fenster schließen ist unter nacktem Xvfb nicht prüfbar (kein `WM_DELETE_WINDOW`); dafür einen Fenstermanager starten oder auf dem Desktop/Steam Deck von Hand prüfen.
8. Testbuilds über `tools/build_testbuild.sh` bauen (eigene Version, eigener Nutzerordner); `build_linux.sh`/`build_windows.sh` tragen bis REL „0.7.0“ – so vorgesehen.
9. Laufzeiten bei Last 20: `check_sprite_geometry.py --jobs 2` 20 min, `--check-keys` ≈ 20 min, Export der Kirche (Cycles) 7 min, `run_tests.sh` 19 min; Hintergrundbefehle enden nach 2 h – lange Ketten teilen.
