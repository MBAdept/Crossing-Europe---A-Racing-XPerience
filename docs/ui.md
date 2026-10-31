# UI und Audio – Modul-Dokumentation

Bildschirme, HUD, Ablauf, Karte und Sound von *Crossing Europe*. Ergänzt [ARCHITECTURE.md](../ARCHITECTURE.md)
(§9 HUD, §10 Ablauf, §11 Audio); die dort beschriebenen APIs bleiben unverändert, Ergänzungen stehen unten.

## Stil

Retro-modern im Stil der 80er-Arcade-Racer, aber ruhig und lesbar bei 1280×720:
tiefes Nachtblau, Magenta (`UiTheme.ACCENT`) und Cyan (`ACCENT_2`) als Akzente, Gold für Hervorhebungen,
schräge Schaltflächen (StyleBoxFlat mit `skew`), Panels mit abgeschrägten Ecken, animierter Synthwave-Hintergrund
(gestreifte Sonne, Berge, Perspektivgitter, Highway).

- **Schriften** (OFL, aus npm `@fontsource`, Lizenzen in `assets/fonts/OFL-*.txt`):
  Orbitron Black (Logo, Countdown), Exo 2 ExtraBold/Bold Italic (Titel, Überschriften, Schaltflächen),
  Barlow Condensed 500/600/700 (Fließtext), Share Tech Mono (Zeiten, Tempo, Zahlen).
  Jede Schrift hat die latin-ext-Variante und danach Godots Standardschrift (Open Sans, u. a. Kyrillisch) als
  Fallback – bulgarische/serbische Namen werden also dargestellt. Pfeil-Glyphen fehlen in allen Schriften:
  Pfeile werden gezeichnet (`KeyHints`, `UiIcons.chevron`), nie als Text.
- **Theme** wird in `UiTheme.theme()` im Code gebaut und an der Menüwurzel (`MenuShell`) bzw. am Pausenmenü gesetzt.
- **Symbole** (Wetter, Tageszeit, Zapfsäule, Radar, Blaulicht, Flaggen, Tempolimit-Schilder) sind Vektorzeichnungen
  in `UiIcons`. Liefert das Sprite-Manifest `ui/weather_*` bzw. `ui/daytime_*`, werden diese Sprites verwendet.
- Texte für Spieler sind deutsch und laufen über `tr()` (in statischen Funktionen `UiFormat.t()`).
  Zahlen im deutschen Format (`12,5 km`), Zeiten wie im Kern (`3:07.50`, `Units.format_race_time`).

## Dateien

| Datei | Inhalt |
|---|---|
| `scripts/ui/game_flow.gd` | Autoload `GameFlow`: Bildschirmablauf, Rennablauf, Debug-Bildschirme |
| `scripts/ui/race_state.gd` | `RaceState`: reine Rennlogik (Legs, Summen, Weltzeit, Pflichtziele, Fähre, Wetter, Routen) |
| `scripts/ui/hud.gd` | `Hud` (API §9), komplett in einem `_draw()` |
| `scripts/ui/pause_menu.gd` | `PauseMenu` (API §9) |
| `scripts/ui/map_view.gd` | `MapView`: Europakarte, Netz, Route, Hervorhebungen, Auto-Zoom |
| `scripts/ui/menu_shell.gd` | `MenuShell`: Theme, Hintergrund, aktueller Bildschirm mit Übergang |
| `scripts/ui/ui_theme.gd`, `ui_kit.gd`, `ui_icons.gd`, `ui_format.gd` | Stil, Bausteine, Symbole, Formatierung |
| `scripts/ui/ui_data.gd`, `sample_data.gd` | Datenzugriff mit Fallbacks, Beispieldaten für Debug-Bildschirme |
| `scripts/ui/route_info.gd` | `RouteInfo`: Routenoption als ganze Route bis zum nächsten Ziel (Fortsetzung, Summen; rein, getestet) |
| `scripts/ui/screens/*.gd` | ein Skript je Bildschirm (Basisklasse `UiScreen`) |
| `scripts/ui/widgets/*.gd` | Hintergrund, Logo-Text, Tastenhinweise, Optionszeile, Laufschrift, Bestenliste, Namenseingabe, Tageszeit-Vorschau, Fahrzeug-Showroom, Routenkarte, Ja/Nein-Abfrage (`ConfirmBox`) |
| `scripts/audio/audio_manager.gd` | Autoload `AudioManager` (API §11) |
| `scripts/audio/sfx_synth.gd` | `SfxSynth`: Klangsynthese (rein, getestet) |
| `scripts/audio/engine_bank.gd`, `engine_gearbox.gd`, `engine_audio.gd` | Motorklang v2: Zyklusbank laden/prüfen, Getriebe/Drehzahl, Mischkern + Wiedergabe (Abschnitt *Motor*) |
| `tools/audio/render_engine_demo.gd` | Demo-WAV einer Motorbank mit geskripteter Fahrt |
| `tests/unit/ui/*` | Tests: Rennlogik, Formatierung, Laufschrift, Audio-Synthese, Getriebe, Karten-Zoom, Routenoptionen (`test_route_info`), Texte aus der Konfiguration (`test_ui_texts`), Gamepad/Fokus/Spielstand (`test_menu_input`), Motor: Bank (`test_engine_bank`), Getriebe (`test_engine_gearbox`), Mischkern (`test_engine_audio`) mit den Testbänken aus `tests/fixtures/engines/` |

## Bildschirmablauf

```
Titel ─┬─ Rennen starten [Abfrage, falls gespeichert] → Rennen wählen → Fahrzeug → Startzeit ─┐
       ├─ Rennen fortsetzen (SaveGame.has_race(); offenes Etappenergebnis → Ergebnis) ───────┤
       │                                                          ▼
       │        ┌──────────── _race_next() ◄──────────────────────────────┐
       │        │  fertig? → Rennergebnis (+ Namenseingabe Rennbestenliste) │
       │        │  >1 Option → Routenwahl ─┐                               │
       │        │  1 Option ───────────────┤                               │
       │        ▼                          ▼                               │
       │   Fähre (Szene, feste Zeit)   Etappenbildschirm → Rennen → Ergebnis ┘
       │        └──────────────────────────────────────────────────────────┘
       ├─ Einzelne Etappe → Etappe/Richtung/Uhrzeit/Wetter → Fahrzeug → Etappenbildschirm → Rennen → Ergebnis
       ├─ Bestenlisten (Rennen + Etappen je Richtung, Filter je Fahrzeug)
       ├─ Optionen (Lautstärken, Vollbild, Spielername, Steuerung)
       └─ Beenden
```

- **Speichern**: nach Rennstart und nach jeder Etappe/Fähre `SaveGame.save_race(race.to_dict())`.
  Nach einer Etappe enthält der Spielstand zusätzlich `pending_result` (das Etappenergebnis), bis dessen
  Ergebnisbildschirm erledigt ist (Name eingetragen oder „Weiter“, `GameFlow.stage_result_done()`): Wird das
  Spiel am Ergebnis bzw. an der Namenseingabe geschlossen, zeigt „Rennen fortsetzen“ dieses Ergebnis erneut.
  Das Rennergebnis löscht den Spielstand (`GameFlow.finish_race()` → `SaveGame.clear_race()`) erst, wenn nichts
  mehr verloren gehen kann: sofort ohne Platzierung, sonst nach der Namenseingabe – bis dahin führt „Rennen
  fortsetzen“ wieder zum Rennergebnis.
- **Nur ein Spielstand**: „Rennen starten“ fragt bei einem gespeicherten Rennen nach (`ConfirmBox`, Standard
  „Abbrechen“, Esc/B = Nein), weil die Bestätigung der Startzeit des neuen Rennens den Spielstand ersetzt.
- **Nächste Etappe**: Start = Ende + `time.stage_pause_hours` (12 h, `EnvironmentModel.next_stage_start`),
  die Pause zählt nicht. **Fähre**: `fixed_time_s` zählt zur Rennzeit, `world_hours` zur Weltzeit; die
  nächste Etappe startet bei Ankunft (die Fähre ersetzt die Pause).
- **Wetter im Rennen**: `RaceState.choose_weather()` nach `weather.race_mode` (`region` →
  `EnvironmentModel.pick_weather(seed, plan.climate)`, `random` gleichverteilt, `fixed` = Feld `weather` der
  Etappe). Der Seed hängt von Renn-Seed, Leg-Nummer und Etappe ab – nach „Fortsetzen“ ist das Wetter gleich.
- **Aufgeben** (Pausenmenü) im Rennen führt zurück zum Etappenbildschirm derselben Etappe; „Etappe neu starten“
  startet sie sofort neu. Abgebrochene Etappen werden nicht gewertet.
- **Bestenlisten**: Namenseingabe, wenn die Zeit in die Top 10 aller Fahrzeuge **oder** des eigenen
  Fahrzeugtyps kommt (`would_rank`); eingetragen wird einmal mit `Leaderboards.submit()`. Der Name wird in
  `Settings.player_name` gemerkt. Kommt die Zeit nur in die Liste des eigenen Fahrzeugs, nennt die
  Überschrift das Fahrzeug („TOP 10 KOMPAKT – PLATZ 3!“ bzw. „RENNEN-TOP-10 KOMPAKT – …“,
  `UiFormat.placement_headline`), und nach der Eingabe erscheint diese Liste mit dem markierten Eintrag
  (`UiData.board_filter_for`) – auf dem Etappen- und dem Rennergebnis gleich.
- **Rekord**: Laufschrift, HUD und Ergebnisvergleich nennen immer den Gesamtrekord (Rekordhalter über alle
  Fahrzeuge). Der Filter (`Settings.leaderboard_filter`) gilt für Bestenlisten-Browser und die Top 10 auf dem
  Etappenbildschirm; die Rennauswahl zeigt den Gesamtrekord und mit Filter zusätzlich die Bestzeit des
  Fahrzeugs („Rekord: … · Kompakt: …“). Startwert des Filters ist `leaderboard.default_filter`, solange der
  Spieler im Browser keinen gewählt hat (kein Eintrag in `user://settings.json`); ungültige Filter fallen
  darauf zurück (`GameFlow.apply_default_leaderboard_filter()`, `UiData.effective_filter`).
- **Routenwahl**: Optionen kommen aus `GameData.next_options()`. Jede Karte zeigt die ganze Route bis zum
  nächsten Pflichtziel (`UiData.route_option` → `RouteInfo`): große Zahl = km bis zum Ziel, „Route über
  Hannover › Kassel › Würzburg“, nächste Etappe mit Länge und Etappenzahl, Summen über alle Etappen bis zum Ziel
  (Autobahn, frei, Radar, Tankstellen, Tunnel, Verkehr, Länder). Die Fortsetzung kommt aus dem Feld
  `continuation` der Option (Datenmodul), sonst aus der kürzesten passenden Route von `race_routes()`, sonst aus
  `via`; `route_km` und eine Zusammenfassung unter `route_summary`/`summary` gewinnen, wenn vorhanden. Die Karte
  hebt die erste Etappe und gestrichelt die Fortsetzung der gewählten Option hervor und beschriftet die
  Zwischenstationen. Rennauswahl zeigt Längen- und Etappenspanne aller Routen (`GameData.race_routes()`/
  `race_summary()` falls vorhanden, sonst Aufzählung mit `next_options`, begrenzt).
- **Etappenbildschirm**: unter den Infokacheln die Etappenbeschreibung (`StagePlan.description`, max. zwei
  Zeilen). Tutorial-Etappen (`StagePlan.tutorial`, Kiel – Hamburg) bekommen einen Kasten „So geht's“:
  Steuerung (Tasten + Gamepad), Tanken (Tankspur, `fuel.lane_trigger_speed_kmh`, Gas bricht ab, Startfüllung
  `StagePlan.start_fuel_fraction`) und Radar (`radar.tolerance` mit Beispiel am ersten Radar der Etappe,
  Polizeiflucht ab `police.escape_speed_kmh`) – `UiFormat.tutorial_tips`.

### Rennstand (`RaceState.to_dict()`)

Format aus ARCHITECTURE.md §10 plus `version`, `race_name`; Legs zusätzlich mit `name`, `penalty_s`,
`distance_km`, `daytime`. `total_time_s` = Summe der Leg-Zeiten (Etappen inkl. Strafen + Fähren).
Im Spielstand optional `pending_result` (`GameFlow.PENDING_RESULT_KEY`, siehe Speichern).

## Bedienung

Tastatur, Gamepad und Maus. Menüs nutzen `ui_accept`/`ui_cancel`/`ui_up/down/left/right` (Gamepad A/B
registriert `InputSetup`, Steuerkreuz/Stick sind in Godots ui_*-Aktionen), jede Seite setzt einen
Standardfokus; der Fokus ist deutlich sichtbar (Magenta-Rahmen mit Glühen, goldene Schrift).
Auswahlwerte (Fahrzeug, Uhrzeit, Optionen, Filter) mit ◀ ▶.

- **Namenseingabe**: Tastatur tippt direkt ins Feld; Gamepad nutzt die Bildschirmtastatur (A–Z, ÄÖÜß,
  Ziffern, Leerzeichen, Löschen, OK): A tippt, B löscht das letzte Zeichen, A im Feld oder auf OK trägt ein.
  Feste Nachbarn: Tastenreihen laufen links/rechts herum, ▲ aus der ersten Reihe ins Feld, ▼ aus der letzten
  Reihe auf Leerzeichen/Löschen/OK.
- **Einzelne Etappe**: Liste links (▲▼ läuft herum, der fokussierte Eintrag wird gewählt), Enter oder ▶ →
  Spalte Richtung/Startzeit/Wetter/Weiter (▲▼ läuft herum, ◀▶ ändern). ◀ auf „Weiter“ und Esc in der Spalte
  führen zum gewählten Eintrag zurück, Esc in der Liste verlässt den Bildschirm. Alle Nachbarn sind explizit
  gesetzt – die geometrische Fokussuche kann nicht mehr in die Liste springen und die Etappe wechseln.
- **Rennergebnis**: Die Etappentabelle hat feste Zeilenhöhe und scrollt bei langen Rennen (Königsrennen:
  40 Etappen + Fähre) – Mausrad oder ▲▼, solange „Hauptmenü“ den Fokus hat (Hinweis „Etappen blättern“).
  Die Routenzeile ist auf zwei Zeilen begrenzt.
- **Abfragen** (`ConfirmBox`): Fokus bleibt in der Box, Standard ist die sichere Antwort, Esc/B = Nein.
- Pausenmenü: Esc/P/Start oder B setzt fort.

Die Flüsse lassen sich mit echten Tastatur-/Gamepad-Ereignissen prüfen (`Input.parse_input_event` in einem
SceneTree-Skript, das `res://scenes/main.tscn` lädt); die Unit-Tests prüfen Verdrahtung und Handler, weil
`tests/run_tests.gd` vor dem Eintritt des Viewports in den Baum läuft.

## HUD

Aufbau siehe Kopf von `scripts/ui/hud.gd`. Die Straßenmitte bleibt frei; Overlays (Countdown, Tanken,
Abschleppen, Nachrichten) erscheinen nur zeitweise. Ergänzungen zum Vertrag:

- Countdown: Ziffern 3-2-1 mit Startampel; „LOS!“ erscheint groß, wenn `countdown` auf -1 springt oder die
  Rennsitzung `show_message("LOS!")` schickt (diese Nachricht wird nicht zusätzlich als Zeile gezeigt).
  Die HUD spielt beim Zahlwechsel `AudioManager.play("beep")` (die Rennsitzung muss das nicht tun; doppelte
  Aufrufe innerhalb von 45 ms werden ohnehin verworfen).
- Nachrichten, die mit „ZIEL!“ beginnen, werden durch das Ziel-Banner (`finished`) ersetzt.
- Tempo-Delta: aktuelle Zeit minus Rekordzeit × zurückgelegter Anteil (`UiFormat.pace_delta`), ab km 0,5.
- Marker im Fortschrittsbalken kommen aus dem `StagePlan` (Tankstellen, Radar, Tunnel, Grenzen, City Limits).
- Länderfarben/-namen aus `GameData.countries`.
- Jedes Frame ruft die HUD `AudioManager.hud_hints(state)` auf (siehe Audio).
- „Nächste Tankstelle“: `next_station_km` 0 (die Rennsitzung schickt 0, solange der Wagen in der Tankspur ist)
  zeigt „hier“, -1 „keine mehr“ (`UiFormat.station_distance`).
- Abschlepp-Overlay beschreibt die Mechanik: Der Wagen bleibt stehen, wo er liegen geblieben ist, der
  Abschleppdienst bringt Sprit (`fuel.tow_refill_fraction`, „für einen halben Tank“), Zeitstrafe
  `fuel.tow_penalty_s` („Weiterfahrt von hier · Zeitstrafe +1:30.00“, `UiFormat.tow_text`).
- Debug: `--hud-demo=refuel,police,radar,radarzone,tow,countdown,reserve,finish,city,understeer` legt
  Demo-Werte über den echten Zustand (Screenshots seltener Situationen).

## Karte (`MapView`)

`set_network(cities, stages, ferries, map_data)`, dann `route`, `route_done`, `highlight`
(`[{from, to, style}]` mit `current`, `option`, `option_selected`, `planned`, `ferry`), `current_city`,
`label_ids`, `fit_to(ids)`. Ländergrenzen aus `data/map/europe_map.json` (§4.5; Polygone werden einmal
trianguliert und als Mesh gezeichnet, Länder der Route heller). Ohne Kartendatei: Meer und Gitter, Netz und
Städte bleiben sichtbar. Städte ohne `map_pos` werden aus `latlon` projiziert (`MapView.project_latlon`).
Debug: `--map-file=<pfad>` lädt eine andere Kartendatei gleichen Formats.

## Audio

Effekte, Schleifen und Menümusik werden beim Start synthetisiert (`SfxSynth`, ca. 0,2 s; Menümusik im
Hintergrund-Thread) und als `AudioStreamWAV` abgespielt – funktioniert mit jedem Audiotreiber inkl. `Dummy`; im
Headless-Betrieb wird nichts abgespielt. Der Motor kommt aus einer Zyklusbank je Auto (Abschnitt *Motor*).

- Busse `Master`, `SFX`, `Music` (werden angelegt), Lautstärken aus `Settings` (`apply_volumes()`).
- Motor ohne Bank (Datei fehlt oder ist ungültig – Rückfall): zwei Schleifen (Last/Schub) mit gleicher Tonhöhe,
  Tonhöhe über ein virtuelles 6-Gang-Getriebe (`SfxSynth.gear_for`: Sägezahn-Drehzahl, kurzer Einbruch beim
  Hochschalten), Gas lauter und heller; `engine_state()` kommt dann aus einem allgemeinen Getriebe
  (`EngineGearbox.generic`).
- Wind ∝ Tempo, Regen, Reifenquietschen beim Untersteuern, Martinshorn (440/587 Hz, „tatü-tata“).
- Einmalklänge `crash, flash, go, beep, finish, fuel_start, fuel_done, ui_move, ui_ok, ui_back`.
- Schleifen und Motor blenden aus, wenn `set_engine()` nicht mehr aufgerufen wird (Szene verlassen) und während der
  Pause. `set_engine()` während der Pause und im selben Frame wie `stop_all()` wird ignoriert (eine Rennszene, die
  gerade freigegeben wird, startet den Motor nicht neu).

Ergänzungen zur API §11: `apply_volumes()`, `set_music(on)`, `hud_hints(state)` (Regen aus `weather` außerhalb von
Tunneln, Quietschen aus `understeer`, Sirenen-Entfernung aus `police_gap_m`; explizite `set_rain`/`set_skid`-Aufrufe
der letzten Sekunde haben Vorrang), `gear_for(speed, vmax, gears)` (statisch, Getriebe der Rückfall-Schleifen), Feld
`sounds_ready`; zum Motor `set_vehicle(id)`, `engine_state()` (beide auch in §11), `preview_engine(id)`
(Fahrzeugwahl: kurzer Gasstoß dieses Autos), `bank_for(id)` (Bank laden/aus dem Cache, `null` = keine),
`engine_perf()` (`{avg_ms, max_ms, frames, samples, skips}` der Live-Wiedergabe).

### Motor (Motorklang v2)

Vertrag, Bankformat und Motoren: [docs/motorsound.md](motorsound.md). Die Rennsitzung ruft beim Aufbau
`AudioManager.set_vehicle(id)` auf; die Bank `audio.engine_bank_dir/<id>.json` wird beim ersten Bedarf geladen und
gemerkt (auch Fehlschläge). Laufzeit in drei reinen, getesteten Klassen:

| Klasse | Aufgabe |
|---|---|
| `EngineBank` (`scripts/audio/engine_bank.gd`) | lädt JSON + Rohdaten (`FileAccess.get_file_as_bytes` → `to_float32_array`), prüft das Format: `errors` = Bank unbrauchbar (Meldung mit `push_error`, Rückfall auf die Schleifen), `warnings` = Abweichung vom Vertrag, die die Laufzeit verträgt (unter 32 kHz, weniger als 8 Varianten, Drehzahlabstand > 1,25, fehlende Ebenenfelder) |
| `EngineGearbox` (`scripts/audio/engine_gearbox.gd`) | Getriebe und Drehzahl aus `gearbox` (unten) |
| `EngineAudio` (`scripts/audio/engine_audio.gd`) | Mischkern, Ebenen, Wiedergabe über `AudioStreamGenerator` |

**Mischkern** (`EngineAudio.render(out, offset, count)`, ohne AudioServer – Tests und Demo nutzen ihn direkt): eine
Zyklusphase (0..1 je Arbeitsspiel) läuft mit der aktuellen Drehzahl. Je Ausgabesample werden die beiden benachbarten
Drehzahlbanken × beide Lasten gelesen, jede an Phase · Periode (Leseschritt Drehzahl / Bankdrehzahl, linear
interpoliert). Gewichte: linear im Logarithmus der Drehzahl zwischen den beiden Punkten, Lasten gleichleistungs-
überblendet (`sin`/`cos` der geglätteten Last, τ 45 ms; Schub × `mix.off_gain`; im Leerlauf mindestens
`mix.idle_load` Last). An jeder Zyklusgrenze wählt jede Bank eine neue zufällige Variante (nie dieselbe zweimal
hintereinander); der alte Zyklus läuft über `overlap − 4` Samples weiter und wird mit Smoothstep ausgeblendet. Pegel,
Last und Überblendungen werden je Block (128 Samples) linear nachgeführt. Ausgang: NaN/inf → 0, weiche Begrenzung ab
0,9 (tanh, nie über 1).

**Getriebe** (`EngineGearbox.update(dt, speed, throttle, vmax, active)`, je Frame): Hochschalten zwischen
`upshift_rpm[0]` (wenig Gas) und `[1]` (Vollgas), Rückschalten zwischen `downshift_rpm[0]` und `[1]` – mit geglättetem
Gas (steigt in 0,15 s für den Kickdown, fällt in 0,8 s, damit kurzes Lupfen den Gang hält); Kickdown überspringt
Gänge. Nahe vmax (keine Beschleunigung mehr) schaltet es in den Gang, der vmax mit weniger Drehzahl hält – bei
passenden Übersetzungen trägt der höchste Gang vmax. Bremsen = Tempo fällt schneller als 15 km/h pro s ohne Gas:
früher zurückschalten, Gang für Gang, bei sportlichen Autos mit Zwischengas. Schaltvorgang = `shift_time_s`
Lastunterbrechung (hoch) bzw. Zwischengas (runter), Drehzahl folgt mit schneller Exponentialkurve. Anfahren: im
1. Gang schleift die Kupplung bei `launch_rpm` (× Gas), bis die Räder aufholen. Stand (oder `active = false`):
neutral (Gang 0), Leerlauf; Gas dreht mit Trägheit bis zum Begrenzer (Countdown). Kein Pendeln: Mindestabstand
zwischen Schaltvorgängen, nach dem Hochschalten 1,2 s kein Rückschalten (außer beim Bremsen), keine Schaltung, deren
neue Drehzahl sofort die Gegenrichtung auslösen würde. Drehzahl immer in [Leerlauf, Begrenzer].

**Ebenen** (aus `layers`/`clips` der Bank, fehlende Ebene = aus): Turbopfeifen prozedural (Sinus; Ladedruck = Last ×
Spool-Kurve ab `boost_rpm` mit Verzögerung `spool_s`, im Stand nur 45 %; Pfeifton zwischen `whistle_hz` je nach
Laderdrehzahl, die beim Gaswegnehmen langsam ausläuft); Gaswegnehmen (Last fällt von über 0,6 unter 0,2, auch nach
einem Zwischengas, nicht beim Hochschalten): Schubumluft-Clip ab `min_boost`, Knall-Clips Poisson-verteilt
(`rate_hz`, abklingend über `duration_s`, ab `min_rpm`, nie zweimal derselbe Clip hintereinander); Begrenzer:
`cut_cycles` Schubzyklen nach `on_cycles` gezündeten Zyklen, Drehzahl sinkt beim Abschalten leicht; Schaltknall
(`shift`) bei Hochschalten unter Last; Startclip beim ersten `set_engine()` nach `set_vehicle()` – die Zyklen blenden
0,3 s vor seinem Ende ein, Drehzahl kurz über dem Leerlauf.

**Wiedergabe**: `AudioStreamGenerator` mit `mix_rate` = Abtastrate der Bank, Puffer `audio.engine_buffer_s`, Bus
`SFX`. Je Frame wird auf `audio.engine_latency_s` Vorlauf gefüllt – mindestens 1,6 Frame-Zeiten (niedrige
Bildrate) und 1,25 × dem größten Block, den der Audiotreiber zwischen zwei Füllungen geholt hat (Treiber mit langen
Mischperioden, z. B. `Dummy` mit ≈ 93 ms). Pause und Szenenwechsel: in 0,12 s ausblenden, danach nicht mehr füllen,
der Player stoppt, sobald die Warteschlange abgespielt ist; Fortsetzen blendet wieder ein. Fahrzeugwahl
(`preview_engine`, `audio.engine_preview`): Leerlauf → Gasstoß (0,25 s nach dem Wechsel, 0,3 s) → Leerlauf,
ausgeblendet nach 1,5 s; ein laufender Gasstoß blendet in 40 ms aus und der neue folgt im selben Datenstrom – sie
überlappen nie.

**Rechenzeit** (GDScript auf dieser Maschine, Bank mit 32 kHz, 533 Samples = ein 60-fps-Frame,
`test_engine_audio.gd::test_cpu_time_per_frame`): vier Quellen + Turbo ≈ 0,44 ms, Begrenzer im Stand ≈ 0,43 ms,
Schub mit Knallen ≈ 0,28 ms (Budget < 1 ms).

**Optionale Bankfelder** (nicht im Vertrag, Standardwerte in Klammern): `mix.idle_load` (0,2: Anteil der Lastbank im
Leerlauf), `gearbox.blip` (Zwischengas beim Bremsen; ja, wenn die Bank einen `shift`-Clip oder eine `crackle`-Ebene
hat), `gearbox.rev_up_s` / `gearbox.rev_down_s` (Hochdrehen im Stand Leerlauf → Begrenzer bzw. zurück; Diesel
0,9/1,6 s, Turbo 0,6/1,25 s, Sauger 0,45/1,05 s).

**Werkzeuge**: `tools/audio/render_engine_demo.gd` rendert eine Bank mit einer geskripteten Fahrt (Start,
Gasstöße, Begrenzer, Vollgas durch die Gänge, Schub, Bremsen) als WAV (Aufruf im Kopf der Datei; `--only-cycles`
nur Zyklen, `--trace` Drehzahl/Gang je Frame als CSV). Testbänke: `tests/fixtures/engines/` aus
`tests/fixtures/make_engine_fixtures.py` (`--demo DIR` schreibt zusätzlich eine V8-Demobank mit vollem
Drehzahlbereich). Debug: `--engine-bank=<pfad.json>` spielt diese Bank für jedes Auto, z. B.
`--engine-bank=res://tests/fixtures/engines/fixture_v4.json` vor dem Einbau der echten Banken.

## GameFlow-API (Ergänzungen)

`boot()` und `start_stage(setup)` wie im Vertrag. Zusätzlich (für die Bildschirme):
`go(name, params, reset_history)`, `back()`, `show_title()`, `current_screen_name()`, `new_race()`,
`select_race(id)`, `select_vehicle(id)`, `select_start_time(hour)`, `continue_race()`, `choose_leg(leg)`,
`ferry_done()`, `stage_setup()`, `start_pending_stage()`, `result_continue()`, `finish_race()`,
`leave_race_to_title()`, `single_stage()`, `configure_single(stage_id, from, hour, weather)`,
`remember_player_name(name)`, `stage_result_done()` (Etappenergebnis erledigt → `pending_result` aus dem
Spielstand), `apply_default_leaderboard_filter()`; Felder `race`, `mode`, `draft`, `single`, `pending_leg`,
`pending_weather`; Konstante `PENDING_RESULT_KEY`.

## Debug und Screenshots

```bash
tools/screenshot.sh /tmp/s --scene=res://scenes/main.tscn --screen=stage_screen --shot-times=1.5
# --screen = title | race_select | vehicle | start_time | stage_select | route_choice | stage_screen |
#            result | race_result | leaderboards | options | ferry
tools/screenshot.sh /tmp/h --stage=dev_testetappe --start-km=8 --autopilot --shot-times=3
tools/screenshot.sh /tmp/p --stage=dev_testetappe --start-km=40 --no-countdown --pause-demo --shot-times=1.5
```

Mit `--screen` laufen die Bildschirme mit Beispieldaten: Ist das echte Netz noch dünn (Stub), wird ein kleines
Beispielnetz um Kiel – Nürnberg verwendet; Bestenlisten werden erzeugt und nur im Speicher gehalten, es wird
nichts nach `user://` geschrieben, „Start“ startet kein Rennen. `--race=<id>` wählt das Rennen der
Rennbildschirme, `--stages-done=<n>` den Fortschritt des Beispielrennens (jeweils erste Option), z. B.
`--screen=stage_screen --stages-done=0` (Tutorial Kiel – Hamburg), `--screen=route_choice --race=koenigsrennen
--stages-done=13` (Wahl bei Saragossa), `--screen=race_result --race=koenigsrennen` (41 Legs).

## Konfiguration

`hud`: `message_s`, `show_fps`, `speedo_max_kmh` (Skalenende Tacho), `messages_max` (gleichzeitige Nachrichten),
`marquee_speed_px_s` (Laufschrift).
`audio`: `master_db`, `engine_db` (Pegel des Motors aus der Bank, zusätzlich zu deren `mix.gain`),
`engine_latency_s` (Vorlauf im Generator, Standard 0,07 s), `engine_buffer_s` (Puffer des Generators, 0,25 s),
`engine_preview` (Gasstoß in der Fahrzeugwahl an/aus), `engine_bank_dir` (Ordner der Motorbänke), nur für den
Rückfall ohne Bank `engine_gears`, `engine_idle_hz`, `engine_max_hz` (Motor-Grundton bei Höchstdrehzahl);
`music_db` (Pegel des Music-Busses), `menu_music` (Menümusik an/aus).

**Zahlen in Spielertexten** kommen aus der Konfiguration, damit sie nach dem Abstimmen (auch per
`game_config.json` neben der ausführbaren Datei) stimmen: Etappenpause `time.stage_pause_hours` und Zeitraffer
`time.time_scale` (Startzeit-Bildschirm, „Nächster Start (12 h Pause)“), Schrittweite
`time.start_hour_step_minutes` (Startzeit-Hinweise), Tankspur `fuel.lane_trigger_speed_kmh` (Optionen,
Tutorial), Abschleppen `fuel.tow_refill_fraction`/`fuel.tow_penalty_s`, Radar `radar.tolerance`, Polizei
`police.escape_speed_kmh`, Startwert des Bestenlisten-Filters `leaderboard.default_filter`.
