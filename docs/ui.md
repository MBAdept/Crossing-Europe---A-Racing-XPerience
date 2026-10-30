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
| `scripts/ui/screens/*.gd` | ein Skript je Bildschirm (Basisklasse `UiScreen`) |
| `scripts/ui/widgets/*.gd` | Hintergrund, Logo-Text, Tastenhinweise, Optionszeile, Laufschrift, Bestenliste, Namenseingabe, Tageszeit-Vorschau, Fahrzeug-Showroom, Routenkarte |
| `scripts/audio/audio_manager.gd` | Autoload `AudioManager` (API §11) |
| `scripts/audio/sfx_synth.gd` | `SfxSynth`: Klangsynthese (rein, getestet) |
| `tests/unit/ui/*` | Tests: Rennlogik, Formatierung, Laufschrift, Audio-Synthese, Getriebe, Karten-Zoom |

## Bildschirmablauf

```
Titel ─┬─ Rennen starten → Rennen wählen → Fahrzeug → Startzeit ─┐
       ├─ Rennen fortsetzen (SaveGame.has_race()) ───────────────┤
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

- **Speichern**: nach Rennstart und nach jeder Etappe/Fähre `SaveGame.save_race(race.to_dict())`;
  das Rennergebnis löscht den Spielstand (`SaveGame.clear_race()`).
- **Nächste Etappe**: Start = Ende + 12 h (`EnvironmentModel.next_stage_start`), die Pause zählt nicht.
  **Fähre**: `fixed_time_s` zählt zur Rennzeit, `world_hours` zur Weltzeit; die nächste Etappe startet bei
  Ankunft (die Fähre ersetzt die 12-h-Pause).
- **Wetter im Rennen**: `RaceState.choose_weather()` nach `weather.race_mode` (`region` →
  `EnvironmentModel.pick_weather(seed, plan.climate)`, `random` gleichverteilt, `fixed` = Feld `weather` der
  Etappe). Der Seed hängt von Renn-Seed, Leg-Nummer und Etappe ab – nach „Fortsetzen“ ist das Wetter gleich.
- **Aufgeben** (Pausenmenü) im Rennen führt zurück zum Etappenbildschirm derselben Etappe; „Etappe neu starten“
  startet sie sofort neu. Abgebrochene Etappen werden nicht gewertet.
- **Bestenlisten**: Namenseingabe, wenn die Zeit in die Top 10 aller Fahrzeuge **oder** des eigenen
  Fahrzeugtyps kommt (`would_rank`); eingetragen wird einmal mit `Leaderboards.submit()`. Der Name wird in
  `Settings.player_name` gemerkt. Der Filter (`Settings.leaderboard_filter`) gilt für Bestenlisten-Browser,
  Top 10 auf dem Etappenbildschirm und Rekorde in der Rennauswahl.
- **Routenwahl**: Optionen kommen aus `GameData.next_options()`; Rennauswahl zeigt Längen- und
  Etappenspanne aller Routen (`GameData.race_routes()`/`race_summary()` falls vorhanden, sonst Aufzählung
  mit `next_options`, begrenzt).

### Rennstand (`RaceState.to_dict()`)

Format aus ARCHITECTURE.md §10 plus `version`, `race_name`; Legs zusätzlich mit `name`, `penalty_s`,
`distance_km`, `daytime`. `total_time_s` = Summe der Leg-Zeiten (Etappen inkl. Strafen + Fähren).

## Bedienung

Tastatur, Gamepad und Maus. Menüs nutzen `ui_accept`/`ui_cancel`/`ui_up/down/left/right`, jede Seite setzt
einen Standardfokus; der Fokus ist deutlich sichtbar (Magenta-Rahmen mit Glühen, goldene Schrift).
Auswahlwerte (Fahrzeug, Uhrzeit, Optionen, Filter) mit ◀ ▶. Namenseingabe: Tastatur tippt direkt ins Feld,
Gamepad nutzt die Bildschirmtastatur (A–Z, ÄÖÜß, Ziffern, Leerzeichen, Löschen, OK); Gamepad-A im Feld trägt ein.
Pausenmenü: Esc/P/Start oder B setzt fort.

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
`remember_player_name(name)`; Felder `race`, `mode`, `draft`, `single`, `pending_leg`, `pending_weather`.

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
nichts nach `user://` geschrieben, „Start“ startet kein Rennen.

## Konfiguration

`hud`: `message_s`, `show_fps`, `speedo_max_kmh` (Skalenende Tacho), `messages_max` (gleichzeitige Nachrichten),
`marquee_speed_px_s` (Laufschrift).
`audio`: `master_db`, `engine_gears`, `engine_idle_hz`, `engine_max_hz` (Motor-Grundton bei Höchstdrehzahl),
`music_db` (Pegel des Music-Busses), `menu_music` (Menümusik an/aus).
