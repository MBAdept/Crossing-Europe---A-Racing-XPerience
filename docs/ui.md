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
- **Mindestgrößen** (Steam Deck, [steam-deck.md](steam-deck.md)): Text mit Kleinbuchstaben ab 17 px (x-Höhe gerendert
  ≥ 9 px), reine Versal-/Ziffernbeschriftung ab 15 px (Versalhöhe 11 px); HUD-Texte, die man beim Fahren liest, 18–19 px.
  Die gedämpfte Farbe `TEXT_MUTED` hat auf den Panels mindestens 4,5:1 Kontrast.
- **Bildformat**: logisch 1280×720 (`canvas_items`). Im Rennen Seitenverhältnis `keep` (16:10 → je 40 px schwarze
  Balken oben und unten), in den Menüs `expand` (`GameFlow._set_menu_stretch`): Die Bildschirme bleiben 1280×720 in der
  Mitte (`MenuShell.layer`), `MenuBackground` ist im selben Rahmen ausgelegt und läuft bis an den Fensterrand weiter;
  `ConfirmBox` und `NameEntryBox` dunkeln das ganze Fenster ab. Bei 16:9 ist beides gleich.
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
| `scripts/ui/widgets/*.gd` | Hintergrund, Logo-Text, Tastenhinweise, Optionszeile, Laufschrift, Bestenliste, Namenseingabe, Bildschirmtastatur als Abfrage (`NameEntryBox`), Tageszeit-Vorschau, Fahrzeug-Showroom, Routenkarte, Ja/Nein-Abfrage (`ConfirmBox`) |
| `scripts/core/input_mode.gd` | `InputMode`: aktives Eingabegerät (Gamepad/Tastatur) für Tastenhinweise und Tutorial |
| `scripts/audio/audio_manager.gd` | Autoload `AudioManager` (API §11) |
| `scripts/audio/sfx_synth.gd` | `SfxSynth`: Klangsynthese (rein, getestet) |
| `tests/unit/ui/*` | Tests: Rennlogik, Formatierung, Laufschrift, Audio-Synthese, Getriebe, Karten-Zoom, Routenoptionen (`test_route_info`), Texte aus der Konfiguration (`test_ui_texts`), Gamepad/Fokus/Spielstand (`test_menu_input`), Eingabegerät/Gamepad-Hinweise/Namenseingabe in den Optionen (`test_steam_deck`) |

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

- **Tastenhinweise je Eingabegerät** (`InputMode`, `KeyHints.visible_hints`): `InputSetup` meldet jedes
  Eingabeereignis an `InputMode`; eine Gamepad-Taste oder ein deutlicher Stick-/Triggerausschlag (≥ 0,5) schaltet auf
  Gamepad, ein Tastendruck zurück, Maus/Touch/Trackpad schalten nicht. Startwert: Gamepad, wenn eines angeschlossen ist
  (Steam Deck: immer). Mit Gamepad zeigen die Fußzeilen nur Gamepad-Symbole: `pad:*` bleibt, Pfeiltasten werden zu einem
  gezeichneten Steuerkreuz (`dpad:udlr`, nur wo der Hinweis keine Gamepad-Taste hat), andere Tasten entfallen; mit
  Tastatur wie bisher Tasten und Gamepad nebeneinander. Weitere Symbole: `pad:LS`/`pad:RS` (Stick).
  Das Tutorial nennt mit Gamepad nur den Gamepad-Tipp (`TutorialCoach.gamepad`, beim Start der Etappe gesetzt).
- **Spielername in den Optionen per Gamepad**: A im Namensfeld öffnet `NameEntryBox` (dieselbe Bildschirmtastatur wie
  bei den Bestenlisten; OK übernimmt, B löscht, Esc auf einer Tastatur schließt ohne Änderung). Hat das Feld den Fokus,
  zeigt die Fußzeile „(A) Bildschirmtastatur“.
- **Vollbild**: Startwert `Settings.default_fullscreen()` – an auf Bildschirmen bis 800 px Höhe (Steam Deck: ein
  1280×720-Fenster mit Titelleiste passt nicht, und nur im Vollbild füllen die Menüs 16:10), sonst aus; danach gilt der
  in den Optionen gespeicherte Wert.
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
- Fortschrittsbalken: Das Panel umfasst auch die km-Angaben darunter (vorher standen sie auf dem Himmel und waren
  bei Tag kaum lesbar); eine Zeitstrafe erscheint als Plakette mittig in dieser Zeile. Lange Etappennamen und
  Rekordhalter werden mit „…“ gekürzt (`_fit`).
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

Alle Klänge werden beim Start synthetisiert (`SfxSynth`, ca. 0,2 s; Menümusik im Hintergrund-Thread) und als
`AudioStreamWAV` abgespielt – funktioniert mit jedem Audiotreiber inkl. `Dummy`; im Headless-Betrieb wird nichts
erzeugt.

- Busse `Master`, `SFX`, `Music` (werden angelegt), Lautstärken aus `Settings` (`apply_volumes()`).
- Motor: zwei Schleifen (Last/Schub) mit gleicher Tonhöhe, Tonhöhe über ein virtuelles 6-Gang-Getriebe
  (`SfxSynth.gear_for`: Sägezahn-Drehzahl, kurzer Einbruch beim Hochschalten), Gas lauter und heller.
  Während des Countdowns (`active = false`) Leerlauf mit Gasstößen.
- Wind ∝ Tempo, Regen, Reifenquietschen beim Untersteuern, Martinshorn (440/587 Hz, „tatü-tata“).
- Einmalklänge `crash, flash, go, beep, finish, fuel_start, fuel_done, ui_move, ui_ok, ui_back`.
- Schleifen blenden aus, wenn `set_engine()` nicht mehr aufgerufen wird (Szene verlassen) und während der Pause.

Ergänzungen zur API §11: `apply_volumes()`, `set_music(on)`, `hud_hints(state)` (Regen aus `weather` außerhalb von
Tunneln, Quietschen aus `understeer`, Sirenen-Entfernung aus `police_gap_m`; explizite `set_rain`/`set_skid`-Aufrufe
der letzten Sekunde haben Vorrang), `gear_for(speed, vmax, gears)` (statisch), Feld `sounds_ready`.

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

Steam Deck: `SCREEN=1280x800 tools/screenshot.sh …` rendert auf einem 1280×800-Bildschirm mit gleich großem Fenster;
die Screenshots zeigen dann das ganze Fenster samt Balken bzw. Menühintergrund. `--input=gamepad|keyboard` legt das
Eingabegerät beim Start fest (Gamepad-Hinweise ohne angeschlossenes Gamepad).

Mit `--screen` laufen die Bildschirme mit Beispieldaten: Ist das echte Netz noch dünn (Stub), wird ein kleines
Beispielnetz um Kiel – Nürnberg verwendet; Bestenlisten werden erzeugt und nur im Speicher gehalten, es wird
nichts nach `user://` geschrieben, „Start“ startet kein Rennen. `--race=<id>` wählt das Rennen der
Rennbildschirme, `--stages-done=<n>` den Fortschritt des Beispielrennens (jeweils erste Option), z. B.
`--screen=stage_screen --stages-done=0` (Tutorial Kiel – Hamburg), `--screen=route_choice --race=koenigsrennen
--stages-done=13` (Wahl bei Saragossa), `--screen=race_result --race=koenigsrennen` (41 Legs).

## Konfiguration

`hud`: `message_s`, `show_fps`, `speedo_max_kmh` (Skalenende Tacho), `messages_max` (gleichzeitige Nachrichten),
`marquee_speed_px_s` (Laufschrift).
`audio`: `master_db`, `engine_gears`, `engine_idle_hz`, `engine_max_hz` (Motor-Grundton bei Höchstdrehzahl),
`music_db` (Pegel des Music-Busses), `menu_music` (Menümusik an/aus).

**Zahlen in Spielertexten** kommen aus der Konfiguration, damit sie nach dem Abstimmen (auch per
`game_config.json` neben der ausführbaren Datei) stimmen: Etappenpause `time.stage_pause_hours` und Zeitraffer
`time.time_scale` (Startzeit-Bildschirm, „Nächster Start (12 h Pause)“), Schrittweite
`time.start_hour_step_minutes` (Startzeit-Hinweise), Tankspur `fuel.lane_trigger_speed_kmh` (Optionen,
Tutorial), Abschleppen `fuel.tow_refill_fraction`/`fuel.tow_penalty_s`, Radar `radar.tolerance`, Polizei
`police.escape_speed_kmh`, Startwert des Bestenlisten-Filters `leaderboard.default_filter`.
