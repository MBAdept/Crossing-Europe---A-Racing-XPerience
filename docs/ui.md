# UI und Audio – Modul-Dokumentation

Bildschirme, HUD, Ablauf, Karte und Sound von *Crossing Europe*. Ergänzt [ARCHITECTURE.md](../ARCHITECTURE.md)
(§9 HUD, §10 Ablauf, §11 Audio); die dort beschriebenen APIs bleiben unverändert, Ergänzungen stehen unten.

## Stil

Retro-modern im Stil der 80er-Arcade-Racer, aber ruhig und lesbar bei 1280×720:
tiefes Nachtblau, Magenta (`UiTheme.ACCENT`) und Cyan (`ACCENT_2`) als Akzente, Gold für Hervorhebungen,
schräge Schaltflächen (StyleBoxFlat mit `skew`), Panels mit abgeschrägten Ecken, animierter Synthwave-Hintergrund
(gestreifte Sonne, Berge, Perspektivgitter, Highway). Der Titelbildschirm zeigt stattdessen das Titelbild
(Abschnitt *Titelbildschirm*).

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
| `scripts/ui/menu_shell.gd` | `MenuShell`: Theme, Hintergrund (Synthwave oder Titelbild, überblendet), aktueller Bildschirm mit Übergang |
| `scripts/ui/attract_mode.gd` | `AttractMode`: Demo nach einer Minute ohne Eingabe im Titel (Kind von `GameFlow`, Abschnitt *Attract-Modus*) |
| `scripts/ui/ui_theme.gd`, `ui_kit.gd`, `ui_icons.gd`, `ui_format.gd` | Stil, Bausteine, Symbole, Formatierung |
| `scripts/ui/ui_data.gd`, `sample_data.gd` | Datenzugriff mit Fallbacks, Beispieldaten für Debug-Bildschirme |
| `scripts/ui/route_info.gd` | `RouteInfo`: Routenoption als ganze Route bis zum nächsten Ziel (Fortsetzung, Summen; rein, getestet) |
| `scripts/ui/screens/*.gd` | ein Skript je Bildschirm (Basisklasse `UiScreen`) |
| `scripts/ui/widgets/*.gd` | Hintergrund, Logo-Text, Tastenhinweise, Optionszeile, Laufschrift, Bestenliste, Namenseingabe, Bildschirmtastatur als Abfrage (`NameEntryBox`), Tageszeit-Vorschau, Fahrzeug-Showroom, Routenkarte, Ja/Nein-Abfrage (`ConfirmBox`), Titelbild mit Ken-Burns-Shader (`TitleBackdrop`), Milchglas-Karte (`GlassPanel`), Demo-Overlay (`AttractOverlay`) |
| `scripts/core/input_mode.gd` | `InputMode`: aktives Eingabegerät (Gamepad/Tastatur) für Tastenhinweise und Tutorial |
| `scripts/audio/audio_manager.gd` | Autoload `AudioManager` (API §11) |
| `scripts/audio/sfx_synth.gd` | `SfxSynth`: Klangsynthese (rein, getestet) |
| `scripts/audio/engine_bank.gd`, `engine_gearbox.gd`, `engine_audio.gd` | Motorklang v2: Zyklusbank laden/prüfen, Getriebe/Drehzahl, Mischkern + Wiedergabe (Abschnitt *Motor*) |
| `scripts/audio/traffic_audio.gd`, `room_audio.gd` | Verkehrsgeräusche und räumliches Martinshorn (`TrafficAudio`), Raumklang mit Tunnelhall und Motorbreite (`RoomAudio`) (Abschnitt *Verkehrsgeräusche, Martinshorn und Raumklang*) |
| `tools/audio/render_engine_demo.gd` | Demo-WAV einer Motorbank mit geskripteter Fahrt |
| `assets/audio/music/title_theme.ogg` | Titelmelodie (Menümusik, Schleife nach dem Intro; Abschnitt *Titelmelodie*) |
| `tools/audio/music_synth.py`, `music_preview.py` | Titelmelodie offline erzeugen; prüfen (Lautheit, Balance, Harmonik, Schleifennaht) und Vorschau |
| `tests/unit/ui/*` | Tests: Rennlogik, Formatierung, Laufschrift, Audio-Synthese, Getriebe, Karten-Zoom, Routenoptionen (`test_route_info`), Texte aus der Konfiguration (`test_ui_texts`), Gamepad/Fokus/Spielstand (`test_menu_input`), Eingabegerät/Gamepad-Hinweise/Namenseingabe in den Optionen (`test_steam_deck`), Motor: Bank (`test_engine_bank`), Getriebe (`test_engine_gearbox`), Mischkern (`test_engine_audio`) mit den Testbänken aus `tests/fixtures/engines/`, Verkehrsgeräusche und Raumklang (`test_traffic_audio`) mit den Platzhalterschleifen aus `tests/fixtures/traffic/`, Attract-Modus und Titelbild (`test_attract_mode`); das ganze Spiel mit Demo: `tests/race/check_attract.gd` |

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
       ├─ Beenden
       └─ 60 s ohne Eingabe: Demo (Attract-Modus, 30 s) ── Taste oder Ende ──► Titel
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
- **Wetter im Rennen**: `RaceState.leg_weather(cfg, plan, seed)` → `RaceState.choose_weather()` nach
  `weather.race_mode` (`region` → `EnvironmentModel.pick_weather(seed, plan.climate)`, `random` gleichverteilt,
  `fixed` = Feld `weather` der Etappe). Der Seed hängt von Renn-Seed, Leg-Nummer und Etappe ab – nach „Fortsetzen“ ist
  das Wetter gleich. Die Tutorial-Etappe (Kiel – Hamburg) fährt immer bei `weather.tutorial_weather` (trocken; Review
  v0.5.0: Regen und Schnee halbieren seitdem fast die Bremsung). `--race-seed=<n>` legt den Renn-Seed fest
  (`run_race.gd`: reproduzierbares Rennwetter).
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

## Titelbildschirm

Hintergrund ist das Titelbild `assets/ui/title_background.webp` (vom Spieler erzeugt, 1672×941: roter Sportwagen von
hinten auf der Autobahn bei Sonnenuntergang Richtung Frankfurter Skyline, Lkw und Transporter vor ihm, rechts eine
beleuchtete Tankstelle). `MenuShell` blendet es für Bildschirme mit `UiScreen.backdrop == "title"` über den
Synthwave-Hintergrund (0,35 s; beim ersten Bildschirm sofort), alle anderen Bildschirme behalten den
Synthwave-Hintergrund. Aufbau:

- **Bild**: `TitleBackdrop`, ein Canvas-Shader über das ganze Fenster: *cover fit* (16:9 zeigt das ganze Bild, 16:10
  auf dem Steam Deck schneidet links und rechts je ~4 % ab, breitere Fenster oben und unten). Leben im Bild, ruhig und
  ohne Effekthascherei: langsamer **Ken-Burns-Zoom** (bis 6,5 % in 45 s hin und zurück) um das rote Auto, dessen
  Brennpunkt in 72 s Richtung Skyline wandert (der Zoom ist eine Konvexkombination – nie ein Bildrand); die tief
  stehende **Sonne atmet** (weiches Glühen, schwacher waagrechter Lichtstreif, 7,2 s); feine **Fahrtstreifen** laufen
  über den Asphalt auf den Betrachter zu – nur zwischen den Fahrbahnrändern unterhalb des Horizonts und hinter den
  Fahrzeugen (Fluchtpunkt, Randsteigungen und Fahrzeugrechtecke sind im Bild vermessen, Konstanten in
  `title_backdrop.gd`). Alle Perioden teilen die 3600-s-Umlaufzeit der Shader-Zeit: kein Sprung. Für die Lesbarkeit
  wird das Bild nach rechts (Logo, Menü) und unten (Tastenhinweise) leicht abgedunkelt.
- **Logo** oben rechts über dem Himmel (Orbitron 66 px, zwei Zeilen, rechtsbündig) auf einem weichen dunklen Hof
  (`TitleBackdrop.halo_texture()`), darunter „A RACING XPERIENCE“ in Cyan mit dunklem Schatten.
- **Menü** auf einer **Milchglas-Karte** (`GlassPanel`) rechts über der Fahrbahn neben den Lkw, wo das Bild am
  wenigsten zählt: Sie zeigt das Bild dahinter weichgezeichnet (Mip-Stufen derselben Textur mit derselben
  Ken-Burns-Abbildung, neun Abtastungen) und dunkelblau getönt, mit abgeschrägten Ecken, einem Rand von Magenta nach
  Cyan und einer hellen Lichtkante oben. Die Schaltflächen sind in Ruhe durchscheinend, der Fokus wie überall
  (Magenta-Rahmen mit Glühen, goldene Schrift); unter einer Linie die Beschreibung des fokussierten Eintrags.
- Die linken zwei Drittel bleiben frei: Sonne, Skyline und das rote Auto (der Held) werden nie verdeckt – auch nicht
  bei stärkstem Zoom und auf 16:10 (`test_attract_mode.gd::test_title_backdrop_cover_fit`).
- Fehlt die Bilddatei, bleibt der Hintergrund dunkelblau und die Karte ein normales halbtransparentes Panel.
- Debug: `--title-time=<s>` verschiebt die Animation (z. B. 22,5 = stärkster Zoom) für Screenshots.
- Ein anderes Bild braucht neue Werte für Sonne, Fluchtpunkt, Fahrbahnränder, Fahrzeuge und Zoom-Brennpunkte
  (Bild-UV 0..1, Konstanten oben in `title_backdrop.gd`).

## Attract-Modus (Demo)

Nach `attract.idle_s` (60 s) ohne Eingabe im Titelbildschirm startet eine Demo von `attract.demo_s` (30 s):
`AttractMode` (Kind von `GameFlow`) blendet über Schwarz in die **echte Rennszene** mit Autopilot, reihum in einer
der kuratierten Szenen aus `attract.scenes` – die nächste Demo zeigt die nächste Szene:

| id | Szene | Etappe, Start | Zeit, Wetter, Auto |
|---|---|---|---|
| `rushhour` | Feierabendverkehr vor Frankfurt (Abendrot, Skyline ab den City Limits) | Dortmund – Frankfurt, km 195 | 18:48, klar, Sportwagen |
| `pyrenaeen` | Schneetreiben in den Pyrenäen (kurvige Landstraße vor dem Somport) | Saragossa – Pau, km 159 | 11:00, Schnee, Kompakt |
| `paris` | Ankunft in Paris (Tunnel du Landy, Pont Alexandre III, Eiffelturm, Haussmann-Häuser) | Lüttich – Paris, km 384,6 | 20:00, Dämmerung, Gran Turismo |
| `hamburg` | Über die Köhlbrandbrücke nach Hamburg (Elbphilharmonie, Michel) | Kiel – Hamburg, km 77 | 12:30, klar, Kombi |
| `regen` | Nachtfahrt im Regen nach Berlin (Autobahn, dann der Fernsehturm) | Leipzig – Berlin, km 158 | 23:00, Regen, Limousine |
| `venedig` | Über die Lagune nach Venedig (Ponte della Libertà, Campanile) | Mailand – Venedig, km 267,6 | 17:30, klar, Sportwagen |
| `wien` | Morgendämmerung in Wien (Riesenrad, Stephansdom) | Budapest – Wien, km 236,5 | 6:18, Morgendämmerung, Kombi |

Felder einer Szene: `id`, `name` (im Overlay), `stage` + `from`, `km`, `hour`, `weather`, `vehicle`, `speed_kmh`
(Starttempo), `cruise_kmh` (Wunschtempo des Autopiloten – er bremst trotzdem für Kurven, Verkehr und Radar; in den
City Limits fährt er im dichten Stadtverkehr mit, ~50 km/h ≈ 5 km in 30 s), optional `lane`, `seed` (Verkehr). Die
Rennsitzung bekommt ein normales Setup (`AttractMode.scene_setup`: `mode: "demo"`, Autopilot ohne Tanken und ohne
Rasen, kein Countdown, Verkehr schon verteilt); Starttempo, reduziertes HUD und Spur setzt `AttractMode` nach dem
Aufbau. Szenen lassen sich ohne Neubau über `game_config.json` neben der ausführbaren Datei ändern.

- **Ton**: Die Titelmusik läuft nahtlos weiter (kein `set_music(false)`; der Musik-Player des AudioManagers läuft
  unabhängig von der Szene). Alle Effekt-Busse – `SFX`, `Room`, `Engine`, `Siren`, `TrafficV<n>` – sind für die
  Demo stumm und danach wieder im Zustand von vorher (ein vom Spieler stummgeschalteter Bus bleibt stumm); `Music`
  wird nie angefasst. Beim Ende hört die Szene zuerst auf zu laufen, `AudioManager.stop_all()` bringt Motor,
  Schleifen und Verkehr sofort zum Schweigen, erst dann werden die Busse zurückgesetzt. Voraussetzung:
  `AudioManager.set_music(true)` startet laufende Musik nicht neu (die Rückkehr zum Titel ruft es auf).
- **Bild**: Overlay `AttractOverlay` im 1280×720-Rahmen des Rennens: oben mittig das Logo in einer Zeile über dem
  Himmel (Wahrzeichen stehen seitlich der Straße und bleiben frei), darunter „DEMO“ und der Name der Szene auf einer
  dunklen Pille; unten links blinkend „Taste drücken“ mit den Symbolen des Eingabegeräts (Gamepad: Ⓐ, Tastatur:
  Enter und Ⓐ) – die Bildmitte unten gehört dem eigenen Auto; am unteren Rand eine dünne Linie, die sich in 30 s
  füllt. Das HUD ist reduziert (`Hud.reduced`): nur Uhr-Panel (Uhrzeit, Wetter, Land, Etappe) und Tacho; keine
  Zeit/Rekord, kein Fortschrittsbalken, kein Tank, keine Schilder- und Polizei-Panels, keine Nachrichten, kein
  Countdown und kein Zielbanner. Seitenverhältnis wie im Rennen (`keep`).
- **Ende**: Jede Taste, Gamepad-Taste, ein deutlicher Stick-/Triggerausschlag (≥ 0,5), ein Mausklick oder Fingertipp
  beendet die Demo **sofort** (Schnitt auf Schwarz, der Titel blendet ein). Das Ereignis wird in `_input` verbraucht,
  bevor die GUI es sieht; dieselbe Taste bleibt bis zum Loslassen wirkungslos (auch das Echo einer gehaltenen Taste)
  und für `attract.guard_s` (0,4 s) jede weitere – so löst das Aufwecken nie einen Menüpunkt aus. Das Gerät, das
  geweckt hat, bestimmt die Hinweise im Titel (`InputMode`). Nach `demo_s` endet die Demo von selbst (über Schwarz),
  ebenso wenn die Etappe in der Demo ins Ziel kommt; danach zählt der Leerlauf-Timer neu.
- **Leerlauf-Timer**: zählt nur, solange der Titel zu sehen und keine Abfrage offen ist (`TitleScreen.has_modal`);
  jede Eingabe (auch Mausbewegung und Loslassen, nicht Stick-Rauschen unter 0,5) setzt ihn zurück. Die Zeiten zählen
  Bildzeit ohne `Engine.time_scale` – echte Sekunden für den Spieler, Videosekunden in einer Movie-Maker-Aufnahme.
- **Nichts wird gespeichert**: Die Demo-Szene ist nicht mit dem Rennablauf von `GameFlow` verbunden
  (`start_attract_stage` statt `start_stage`; `stage_finished`/`stage_aborted` beenden nur die Demo) – kein
  Spielstand, keine Bestenliste, keine Einstellungen. `tests/race/check_attract.gd` prüft das mit einer Demo, deren
  Etappe ins Ziel kommt (`savegame.json`, `leaderboards.json`, `settings.json` samt `.bak`/`.tmp` nach Größe, Zeit
  und MD5 unverändert, keine neuen Bestenlisten-Einträge im Speicher).
- **Steam Deck**: Der eingebaute Controller weckt wie jedes Gamepad, Touchscreen-Tipps und Trackpad-Klicks wie die Maus.
- **Debug**: `--attract-after=<s>` (Leerlaufzeit), `--attract-scene=<index|id>` (erste Szene),
  `--attract-demo-s=<s>`, `--attract-press=<s>` (Aufnahmen: Enter nach s Sekunden der ersten Demo, über den Viewport
  wie eine echte Taste), `--no-attract`. Screenshots einer Szene:
  `tools/screenshot.sh /tmp/a --scene=res://scenes/main.tscn --attract-after=0.5 --attract-scene=paris --shot-times=4,12,21`;
  Video mit Ton siehe *Debug und Screenshots*.
- **Tests**: `test_attract_mode.gd` (Leerlauf-Timer, welche Eingaben wecken, Verschlucken bis zum Loslassen und in der
  Schutzzeit, Dauer und nächste Szene, Busse stumm und zurück, Szenen gegen das Streckennetz, Setup,
  Titelbild-Abbildung) und `tests/race/check_attract.gd` (das ganze Spiel headless, Teil von `tools/run_tests.sh`:
  Titel → Demo → von selbst zurück → nächste Szene → Enter / Gamepad A / Klick beenden ohne Menüpunkt → Ziel in der
  Demo → nichts gespeichert; unter Xvfb ohne `--headless` misst es zusätzlich, dass die Titelmusik durchgehend
  weiterläuft).

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
- `reduced` (Attract-Modus): nur Uhr-Panel und Tacho – keine Nachrichten, Banner oder übrigen Panels.

## Karte (`MapView`)

`set_network(cities, stages, ferries, map_data)`, dann `route`, `route_done`, `highlight`
(`[{from, to, style}]` mit `current`, `option`, `option_selected`, `planned`, `ferry`), `current_city`,
`label_ids`, `fit_to(ids)`. Ländergrenzen aus `data/map/europe_map.json` (§4.5; Polygone werden einmal
trianguliert und als Mesh gezeichnet, Länder der Route heller). Ohne Kartendatei: Meer und Gitter, Netz und
Städte bleiben sichtbar. Städte ohne `map_pos` werden aus `latlon` projiziert (`MapView.project_latlon`).
Debug: `--map-file=<pfad>` lädt eine andere Kartendatei gleichen Formats.

## Audio

Effekte und Schleifen werden beim Start synthetisiert (`SfxSynth`, ca. 0,2 s) und als `AudioStreamWAV` abgespielt –
funktioniert mit jedem Audiotreiber inkl. `Dummy`; im Headless-Betrieb wird nichts abgespielt. Die Menümusik ist die
Titelmelodie `assets/audio/music/title_theme.ogg` (Abschnitt *Titelmelodie*); fehlt die Datei, wird wie früher eine
kurze Synthwave-Schleife im Hintergrund-Thread synthetisiert. Der Motor kommt aus einer Zyklusbank je Auto (Abschnitt
*Motor*); Verkehr, Martinshorn und Raumklang: Abschnitt *Verkehrsgeräusche, Martinshorn und Raumklang*.

- Busse `Master`, `SFX`, `Music` (werden angelegt), Lautstärken aus `Settings` (`apply_volumes()`); dazu `Room` (→ `SFX`,
  Raumklang), `Engine` (→ `Room`, eigener Motor), `TrafficV0` … `TrafficV<n-1>` und `Siren` (→ `Room`, je ein Tiefpass).
- Motor ohne Bank (Datei fehlt oder ist ungültig – Rückfall): zwei Schleifen (Last/Schub) mit gleicher Tonhöhe,
  Tonhöhe über ein virtuelles 6-Gang-Getriebe (`SfxSynth.gear_for`: Sägezahn-Drehzahl, kurzer Einbruch beim
  Hochschalten), Gas lauter und heller; `engine_state()` kommt dann aus einem allgemeinen Getriebe
  (`EngineGearbox.generic`).
- Wind ∝ Tempo, Regen, Reifenquietschen beim Untersteuern, Martinshorn (440/587 Hz, „tatü-tata“; räumlich an der
  Polizei, wenn die Rennsitzung sie in `set_traffic()` mitschickt).
- Einmalklänge `crash, rail, flash, go, beep, finish, fuel_start, fuel_done, ui_move, ui_ok, ui_back`; `play(name, gain_db)` hebt/senkt den Pegel (Leitplankentreffer `rail`: −10 dB bei leichter Berührung bis +2 dB beim Hineinrutschen, skaliert mit `vehicle.rail_impact`).
- Schleifen und Motor blenden aus, wenn `set_engine()` nicht mehr aufgerufen wird (Szene verlassen) und während der
  Pause. `set_engine()` während der Pause und im selben Frame wie `stop_all()` wird ignoriert (eine Rennszene, die
  gerade freigegeben wird, startet den Motor nicht neu).

Ergänzungen zur API §11: `apply_volumes()`, `set_music(on)`, `hud_hints(state)` (Regen aus `weather` außerhalb von
Tunneln, Quietschen aus `understeer`, Sirenen-Entfernung aus `police_gap_m`; explizite `set_rain`/`set_skid`-Aufrufe
der letzten Sekunde haben Vorrang), `gear_for(speed, vmax, gears)` (statisch, Getriebe der Rückfall-Schleifen), Feld
`sounds_ready`; zum Motor `set_vehicle(id)`, `engine_state()` (beide auch in §11), `preview_engine(id)`
(Fahrzeugwahl: kurzer Gasstoß dieses Autos), `bank_for(id)` (Bank laden/aus dem Cache, `null` = keine),
`engine_perf()` (`{avg_ms, max_ms, frames, samples, skips}` der Live-Wiedergabe); zu Verkehr und Raum
`set_traffic(vehicles, listener)` und `set_environment(env)` (beide auch in §11), `traffic_state()` (Stimmen des letzten
Frames, Hörer, Martinshorn, Tunnelüberblendung) und `traffic_perf()` (`{avg_ms, max_ms, frames, apply_avg_ms,
apply_max_ms}`: GDScript-Zeit je Frame). Mit `--perf` gibt der AudioManager beim Beenden `AUDIO_PERF` aus.

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

### Verkehrsgeräusche, Martinshorn und Raumklang

Vertrag: [docs/verkehrsgeraeusche.md](verkehrsgeraeusche.md). Die Rennsitzung ruft jedes Frame
`AudioManager.set_traffic(cars, {z, x, speed})` mit der Fahrzeugliste des Renderers (`id`, `set`, Heck `z`, `x`, `length`,
`speed` in km/h, `heavy`; Polizei mit `id` −2) und der Verfolgerkamera auf, dazu `set_environment({"tunnel": Kamera im
Tunnel})`; nach dem Etappenergebnis nicht mehr (der Verkehr blendet aus). Zwei Klassen:

| Klasse | Aufgabe |
|---|---|
| `TrafficAudio` (`scripts/audio/traffic_audio.gd`) | lädt `traffic_sounds.json` und die WAVs, rechnet je Frame Stimmenzuteilung, Pegel, Panorama, Tonhöhe und Luftdämpfung (rein: `update()`, ohne AudioServer getestet) und gibt sie an die Player (`attach()`/`apply()`) |
| `RoomAudio` (`scripts/audio/room_audio.gd`) | Busse `Room` und `Engine` mit ihren Effekten, Überblendung beim Ein- und Ausfahren in Tunnel |

**Klänge**: `audio.traffic_sounds` (`res://assets/audio/traffic/traffic_sounds.json`). Fehlt die Datei, gibt es keine
Verkehrsgeräusche (nur ein Hinweis in der Konsole, kein Fehler); das Martinshorn spielt trotzdem. Eine unbrauchbare Datei
(Format, Klasse `car` fehlt) meldet `push_error`; Klassen mit fehlendem Klang werden mit Warnung verworfen (ihre Fahrzeuge
klingen wie `car`). Godot importiert die WAVs; die Laufzeit nimmt je eine Kopie ohne Pfad und schaltet deren Schleife ein
(vorwärts über das ganze Sample). Modell aus der Sprite-ID (`traffic/<modell>_<farbe>`, `police/<land>`; unbekannte
schwere Fahrzeuge zählen als `truck`, sonst `car`). Debug: `--traffic-sounds=res://tests/fixtures/traffic/traffic_sounds.json`
spielt die Platzhalter, bis die echten Klänge da sind.

**Modell** (je Frame, `TrafficAudio.update`):

- Hörer = Kamera + `traffic_listener_ahead_m` (3 m) entlang der Straße; x quer, z längs in Metern, Kurven vernachlässigt
  (die Straße scrollt mit dem echten Tempo: km/h / 3,6 = m/s).
- Quelle = Fahrzeugachse vom Heck zur Front. Abstand und Richtung gehen zum nächsten Punkt dieser Strecke (ein Lkw bleibt
  „neben“ einem, solange er neben einem ist), der Doppler zur Mitte.
- Pegel = `traffic_db` + `gain_db` + `level_db_per_decade · log10(v / ref_kmh)` + Entfernung: bis `traffic_ref_m` × Größe
  voll, dann (Bezug/Abstand)^`traffic_rolloff` (Luft: hoch 2 – das „Wusch“ nur nah), zwischen 70 und 100 % von
  `traffic_max_m` (150 m) weich auf 0.
- Panorama mit gleicher Leistung aus sin(Azimut) × `traffic_pan` (0,85: direkt neben einem ~19 dB Unterschied zwischen
  den Kanälen). Vorn und hinten sind in Stereo gleich.
- Tonhöhe = clamp((v / ref_kmh)^pitch_exp, 0,6, 1,6) × Doppler × Streuung (±6 %, fest je Fahrzeug-ID wie die
  Motorvariante und die Startposition in der Schleife).
- Doppler = c / (c − k · v_Annäherung): Annäherung aus der Relativgeschwindigkeit längs der Straße entlang der Sichtlinie,
  k = `traffic_doppler` (2 = doppelt so deutlich wie echt), |k · v| ≤ c/2, über 80 ms geglättet.
- Luftdämpfung: Tiefpass 20 kHz / (1 + Abstand / `traffic_air_m`) (30 m: bei 150 m 3,3 kHz).
- Stimmen: `traffic_voices` (6) Plätze aus Motor + Reifen + Luft. Die nächsten Fahrzeuge (Lkw/Busse zählen 1,45-mal
  näher) bekommen einen Platz; wer einen hat, behält ihn, bis ein anderes um `traffic_hysteresis` (25 %) näher ist. Ein-
  und Ausblenden in `traffic_fade_s` (0,3 s); ein freigegebener Platz wird erst wieder vergeben, wenn er still ist. Pause
  oder keine Aufrufe (0,35 s): alles blendet aus; `stop_all()`: sofort still.
- Martinshorn: eigener Platz an der Polizei (`id` −2) mit Panorama, Doppler und Luftdämpfung; Pegel `siren_db` (wie die
  alte Mono-Schleife) bis `siren_ref_m`, dann (Bezug/Abstand)^`siren_rolloff` bis `siren_max_m`, nie unter `siren_floor`,
  solange es läuft (eine Verfolgung aus 320 m bleibt hörbar). Ein/aus kommt wie bisher aus `set_siren()`/`hud_hints()`;
  ohne Polizei in der Fahrzeugliste spielt es mittig mit der alten Lautstärkekurve.

**Wiedergabe**: `AudioStreamPlayer2D` in einer eigenen, nicht gezeichneten Welt (`SubViewport` mit `AudioListener2D`).
Godot verteilt jede Wiedergabe mit Kanalpegeln, die es über jeden Mischblock rampt – Panorama- und Pegeländerungen
knacken nicht. Aus den gewünschten Pegeln (links, rechts) wird Lautstärke = links + rechts und Position
x = (2 · rechts / (links + rechts) − 1) · 64 px (Godots lineares 2D-Panorama, `panning_strength` =
1 / `audio/general/2d_panning_strength`). Je Platz ein Bus `TrafficV<n>` bzw. `Siren` mit Tiefpass (Luftdämpfung), alle
→ `Room`. Werte werden nur gesetzt, wenn sie sich ändern.

**Raumklang** (`RoomAudio`):

- Bus `Room` (→ `SFX`) für Motor, Verkehr und Martinshorn: frühe Reflexionen (`AudioEffectDelay`, 17/23 ms, leicht
  links/rechts, `reflections_db` −16 dB draußen, `reflections_tunnel_db` −8 dB im Tunnel) und Tunnelhall
  (`AudioEffectReverb`: `reverb_room_size` 0,86, `reverb_damping` 0,45, `reverb_predelay_ms` 22 mit
  `reverb_predelay_feedback` 0,3, `reverb_hipass` 0,03; Anteil `reverb_wet` 0 draußen … `reverb_tunnel_wet` 0,3 im
  Tunnel). Der Anteil folgt der Kamera im Tunnel linear in `reverb_fade_s` (0,8 s), abgebildet mit Smoothstep.
- Bus `Engine` (→ `Room`) für den eigenen Motor (auch die Rückfall-Schleifen): kurzer, diffuser Stereohall
  (`engine_width` 0,6) mit Hochpass davor (`engine_width_hipass` 0,1 ≈ 600 Hz; Godots `hipass` 0..1 = 0..6 kHz). Die
  starken tiefen Motortöne bleiben mono, darüber mitteln sich viele Teiltöne – breiter, aber mittig. (Der erste Versuch,
  je eine feste Verzögerung links und rechts, filtert den harmonischen Motor je Kanal verschieden und zog ihn
  drehzahlabhängig bis 1,7 dB zur Seite.)
- Probehören in der Fahrzeugwahl, Einmalklänge, Wind, Regen und Quietschen bleiben trocken auf `SFX`.

**Messungen** (Movie-Maker-Aufnahmen des echten Spiels mit `tests/race/shoot_vehicles.gd`, Platzhalterklänge; für die
Verkehrsmessungen ist der eigene Motor stumm):

| Prüfung | Ergebnis |
|---|---|
| Auto links überholt (`passby`, 150 gegen 105 km/h) | links bis 9 dB lauter, solange es links ist; danach mittig (0,1 dB) |
| Tonhöhe beim Passieren | Grundton 71,5 → 62,5 Hz (Verhältnis 1,14, berechnet 1,15); folgt dem Protokoll auf ±1–2 % |
| Lkw rechts (`overtake`) | ~1,2 s lang rechts 11–13 dB lauter, Spitze 5,4 dB über dem Pkw, tiefer (63,8 → 52,1 Hz, Verhältnis 1,22, berechnet 1,23) |
| Martinshorn (`police`) | kommt links von hinten (links bis 17 dB lauter), 440-Hz-Ton 471 → 402 Hz beim Passieren (±1,5 % zum Protokoll), danach mittig 16 m voraus |
| Tunnel (`tunnel` ab km 49,7) | Hall blendet beim Einfahren der Kamera in 0,8 s ein, L/R-Korrelation fällt von ~0,93 auf 0,3–0,6; Impulsantwort: Nachhallzeit 2,2–2,5 s, Hall/Direkt −2 dB; draußen nur die frühen Reflexionen (−13,6 dB, kein Nachhall) |
| Stimmenwechsel (`overtake_cars` mit nur einer Stimme) | kein Knacken: Spitzen der Ableitung beim Zuteilen 0,2–0,6 × des 95. Perzentils, Pegelsprünge wie im übrigen Signal |
| Eigener Motor (Rennen ab km 30, Autopilot) | L/R-Korrelation vorher 1,000, nachher 0,885 (je Sekunde 0,84–0,94), Balance ±0,3 dB |
| Rechenzeit | `update()` ohne AudioServer 0,05 ms (41 Fahrzeuge) bzw. 0,09 ms (161); im Rennen zur Hauptverkehrszeit (Software-Rendering, Movie Maker) 0,23 ms je Frame samt Playern (`traffic_perf()`) |

**Werkzeuge**: `tests/race/shoot_vehicles.gd -- --scenario=passby|overtake|overtake_cars|police|tunnel` mit
`--write-movie <datei>.avi` (Bild und Ton), `--traffic-sounds=…`, `--audio-trace=<datei.csv>` (Stimmen je Frame:
Fahrzeug, Abstand, Panorama, Doppler, Pegel, Tunnelüberblendung) und `AUDIO_PERF` am Ende; `--mute-bus=Engine` (nur
Verkehr hören), `--audio-config=engine_width=0,traffic_db=-3` (Werte für einen Lauf ändern, ohne die gemeinsame
`user://`-Konfiguration). Platzhalter: `tests/fixtures/make_traffic_fixtures.py` → `tests/fixtures/traffic/` (16 kHz,
1,6 s, jede Schleife RMS −15 dBFS). Mit dieser Lautheit ist `traffic_db` = −4 dB eingestellt; haben die echten Schleifen
eine andere, `traffic_db` um die Differenz anpassen.

### Titelmelodie

Synthwave-Rock im Outrun-Stil, 128 bpm, E-Moll, 3:22,5 min: `assets/audio/music/title_theme.ogg` (Ogg Vorbis q5,
44,1 kHz Stereo, 3,7 MB), erzeugt offline mit `tools/audio/music_synth.py` (python3 + numpy, ffmpeg nur für die
Vorbis-Kodierung; deterministisch – zwei Läufe ergeben eine bitgleiche Datei –, ca. 5 min). Das **Intro** (Takt 1–8, 0:00–0:15) läuft einmal, danach die
**Schleife** (Takt 9–108, 3:07,5 min) ohne Ende: Import-Einstellungen `loop=true`, `loop_offset=15` (die `.import`
schreibt das Werkzeug mit). Das Intro ist genau 661 500 Samples lang – Godots Sprung an den Schleifenbeginn ist
sampelgenau (Test `test_title_theme_seam_through_godot_playback`).

- **Abspielen**: `AudioManager.set_music(true)` startet die Titelmelodie von vorn (Intro), `set_music(false)` stoppt
  sie; weitere `set_music(true)`, während sie läuft, ändern nichts (Bildschirmwechsel, Attract-Mode), `stop_all()` lässt
  die Musik in Ruhe. Datei aus `audio.music_file`; fehlt sie oder ist sie kein Audiostream, spielt die alte
  synthetisierte Schleife (`SfxSynth.music_loop`, um `FALLBACK_MUSIC_DB` = +5 dB angehoben, damit sie so laut bleibt
  wie früher).
- **Pegel**: gemastert auf −14 LUFS integriert (ITU-R BS.1770-4), True Peak ≤ −1 dBTP auch nach der Vorbis-Kodierung;
  Music-Bus `audio.music_db` −9 dB (vorher −4 dB mit der alten Schleife von −20 LUFS) – im Mittel rund 1 dB lauter als
  die alte Menümusik, in den lauten Teilen rund 2,5 dB.

| Zeit | Takte | Abschnitt | Akkorde | Inhalt |
|---|---|---|---|---|
| 0:00 | 1–8 | Intro (einmal) | Em Em C C Am Am D B | FM-Glocken spielen das Motiv, Pad, Bass-Drone, Arpeggio öffnet den Filter; ab Takt 5 Hi-Hats, Kick, gedämpfte Gitarren, Snare-Wirbel, Riser; Takt 7–8 Turnaround D–B mit Stabs und Tom-Fill |
| 0:15 | 9–16 | Thema (Schleifenbeginn) | Em C G D ×2 | Hook auf der Leadgitarre (Synth im Unisono), Rhythmusgitarren im 3-3-2-Akzent, Oktavbass, Four-on-the-floor mit Gated-Snare und Clap |
| 0:30 | 17–32 | Strophe 1 | Em Em C D ×4 | Palm-Mute-Achtel, Rockbeat, Arpeggio; ab Takt 25 Strophenmelodie (weicher Synth) |
| 1:00 | 33–40 | Pre-Chorus 1 | Am Am C C D D B B | offene Akkorde, Synth-Brass, steigende Melodie (über B7 in den Refrain), Snare-Wirbel, Riser |
| 1:15 | 41–48 | Refrain 1 | Em C G D ×2 | Hook auf dem Synth-Lead, Gitarrenwand aus offenen Achteln |
| 1:30 | 49–56 | Strophe 2 | Em Em C D ×2 | Strophe mit Melodie, Ghost-Hi-Hats |
| 1:45 | 57–64 | Pre-Chorus 2 | wie Pre-Chorus 1 | |
| 2:00 | 65–72 | Refrain 2 | Em C G D ×2 | Hook mit Terz-Harmoniestimme |
| 2:15 | 73–80 | Bridge | C G D Em C G D D | Breakdown: Glocken, Pad, Arpeggio, Puls-Bass; Halftime, Snare-Wirbel |
| 2:30 | 81–88 | Gitarrensolo | Em C G D Em C D E | Bends, Vibrato, schnelle Läufe; E-Dur und ein Bend auf Fis führen in den Tonartwechsel |
| 2:45 | 89–104 | Schlussrefrain | F♯m D A E ×4 | Hook einen Ganzton höher (Fis-Moll), Harmoniestimme, Leadgitarre eine Oktave tiefer |
| 3:15 | 105–108 | Ausklang | F♯m F♯m D B | Schlussakkord mit Tom-Wirbel, dann derselbe Turnaround wie im Intro → zurück zum Thema |

**Hook**: aufsteigender e-Moll-Dreiklang und fallende Linie im 3-3-2-Rhythmus (E–G–H, A–G–Fis), über G wiederholt
(D–G–H, A–G–A), in Takt 7 bis zum hohen D; im Thema auf der Leadgitarre, in den Refrains auf dem Synth-Lead, im
Schlussrefrain einen Ganzton höher – der „Gangwechsel“ des Rennspiels.

**Klangerzeugung** (alles numpy, keine Samples): Kick (Sinus mit Tonhöhenhüllkurve, Schlägelklick, Sättigung),
Snare und Toms mit 80er-Gated-Reverb (dichter Raum, nach 0,25–0,32 s abgeschnitten; Toms auf E–H–E gestimmt), Clap,
Hi-Hats im 808-Stil (sechs Rechteckschwingungen + Rauschen), Becken aus 70 unharmonischen Teiltönen, Reverse-Becken,
Riser (Rauschband 300 Hz → 9 kHz), Impacts; Bass als gezupfte Saite (Teiltöne mit Inharmonizität, Zupf- und
Tonabnehmer-Position) plus Synth-Bass (Sägezahn durch ein 4-Pol-Ladder-Filter mit Hüllkurve); **Rhythmusgitarren**:
Powerchords aus gezupften Saitenmodellen (Anschlag nacheinander, Plektrumrauschen, Palm Mutes mit stark gedämpften
Obertönen), zwei unabhängige Takes hart links/rechts (Korrelation ≈ 0), durch ein Verstärkermodell (Vor-EQ mit
Mittenbuckel, zwei asymmetrische tanh-Stufen bei 4× Überabtastung, Klangregelung, 4×12-Box als minimalphasiges FIR);
Leadgitarre mit Bends, Vibrato, Slides durch einen heißeren Verstärker; Pad (verstimmte Sägezahn-Wavetables, Chorus),
Arpeggiator (Ladder-Filter-Pluck), Synth-Brass, FM-Glocken, Synth-Lead (zwei verstimmte Sägezähne + Suboktave,
Portamento, verzögertes Vibrato).

**Mischung und Mastering**: EQ je Spur (minimalphasige FIRs aus analogen Prototypen), Pegel je Spur als K-gewichtete
Ziel-Lautheit (`MIX`), Abschnitts-Automation (`AUTOMATION`: Strophen und Bridge zurückgenommen, Solo-Gitarre vorn),
Sidechain-Ducking von Pad, Synth-Bass und Arpeggio durch die Kick, Sends auf Plate und Hall (synthetische
Stereo-Impulsantworten mit frequenzabhängiger Nachhallzeit) und ein punktiertes Ping-Pong-Delay, Parallelkompression
der Drums; Master: EQ (`MASTER_EQ`), Glue-Kompressor 2:1, Bass unter 120 Hz mono, Lookahead-True-Peak-Limiter
(Lautheit iterativ auf −14 LUFS).

**Nahtlose Schleife**: Die letzten zwei Takte des Ausklangs sind dieselben Ereignisse wie die letzten zwei des Intros
(Turnaround D–B, gleiche Zufallszahlen), alle Modulationen laufen im Takt (Chorus 1 Zyklus je Takt), die Detektoren der
Kompressoren arbeiten in Blöcken von 63 Samples (teilt Intro- und Schleifenlänge). Das Werkzeug rendert nach dem
Ende der Schleife deren Fortsetzung (Thema, 4 Takte): Was die Schleife nach der Naht spielt, weicht von dieser echten
Fortsetzung um weniger als −95 dBFS ab – Nachhall, Delays, klingende Noten und Kompressorzustand gehen über die Naht.

**Prüfen ohne Hinhören**: `python3 tools/audio/music_preview.py --out DIR [--master DIR/master_full.wav]` (Master aus
`music_synth.py --wav DIR`) misst die dekodierte OGG-Datei so, wie das Spiel sie abspielt: Lautheit und
Lautheitsumfang (EBU Tech 3342), True Peak, Lautheit je Abschnitt, Terzband-Spektrum gegen eine Rock/Pop-Zielkurve,
Stereo-Korrelation, Mono-Bass, Akkord je Takt (Chroma aus tonalen Spektralspitzen gegen die Akkorde des Arrangements)
und Tonart je Abschnitt, die Schleifennaht (Sprung an der Naht gegen die Sprungstatistik der Datei, Hochpass-Klick-
detektor, Abweichung von der echten Fortsetzung); Bilder `spectrogram.png`, `loudness.png`, `seam.png`,
`overview.png`, Tabelle `sections.md`, Vorschau `title_theme_preview.mp3` (Datei + 20 s zweiter Durchlauf),
`seam_demo.mp3` (12 s vor und nach der Naht) und `title_theme_preview.mp4` (Spektrogramm mit Abspielmarke).

| Messung (dekodierte Datei) | Ergebnis |
|---|---|
| Lautheit | −14,1 LUFS integriert (Master −14,0), Lautheitsumfang 4,6 LU, True Peak −1,1 dBTP, kein Sample übersteuert |
| Abschnitte (Kurzzeit-Lautheit, Mittel) | Intro −17,6, Thema −13,7, Strophen −16,1/−15,3, Pre-Chorus −13,7, Refrains −12,9/−12,8, Bridge −16,8 (Breakdown bis −19), Solo −13,5, Schlussrefrain −12,8 LUFS |
| Klangbalance | Terzbänder 63 Hz – 16 kHz innerhalb ±3,5 dB der Zielkurve (50 Hz tiefer: e-Moll-Basslinien liegen bei 41 und 82 Hz) |
| Stereo | Korrelation 0,65–0,84 je Abschnitt, Bass unter 120 Hz mono (0,98–0,99), die zwei Gitarren-Takes untereinander ≈ 0 |
| Harmonik | 101 von 108 Takten als der vorgesehene Akkord erkannt (alle Grundtöne richtig; der Rest: Terz der verzerrten Powerchords), Tonart E-Moll bzw. im Schlussrefrain Fis-Moll |
| Schleifennaht | Sprung an der Naht 0,38 × des 99,9. Perzentils der Datei, kein Hochton-Klick (Energie wie in der Umgebung), Abweichung von der echten Fortsetzung −101 dB; Godot spielt nach der Naht exakt die Samples ab `loop_offset` |
| Im Spiel (Movie Maker, Titelbildschirm) | Musik startet mit dem Bildschirm, Pegel −14,05 dB unter der Datei (= `music_db` −9 dB + Musiklautstärke 0,7 + Master 0,8), −28,7 LUFS |

## GameFlow-API (Ergänzungen)

`boot()` und `start_stage(setup)` wie im Vertrag. Zusätzlich (für die Bildschirme):
`go(name, params, reset_history)`, `back()`, `show_title()`, `current_screen_name()`, `new_race()`,
`select_race(id)`, `select_vehicle(id)`, `select_start_time(hour)`, `continue_race()`, `choose_leg(leg)`,
`ferry_done()`, `stage_setup()`, `start_pending_stage()`, `result_continue()`, `finish_race()`,
`leave_race_to_title()`, `single_stage()`, `configure_single(stage_id, from, hour, weather)`,
`remember_player_name(name)`, `stage_result_done()` (Etappenergebnis erledigt → `pending_result` aus dem
Spielstand), `apply_default_leaderboard_filter()`, `start_attract_stage(setup)` (Rennszene einer Demo: die
Musik läuft weiter, die Signale gehen an `AttractMode`, nichts wird gespeichert); Felder `race`, `mode`, `draft`,
`single`, `pending_leg`, `pending_weather`, `attract` (`AttractMode`); Konstante `PENDING_RESULT_KEY`.

## Debug und Screenshots

```bash
tools/screenshot.sh /tmp/s --scene=res://scenes/main.tscn --screen=stage_screen --shot-times=1.5
# --screen = title | race_select | vehicle | start_time | stage_select | route_choice | stage_screen |
#            result | race_result | leaderboards | options | ferry
tools/screenshot.sh /tmp/h --stage=dev_testetappe --start-km=8 --autopilot --shot-times=3
tools/screenshot.sh /tmp/p --stage=dev_testetappe --start-km=40 --no-countdown --pause-demo --shot-times=1.5
```

Titelbild und Demo: `--title-time=<s>` (Ken-Burns-Phase), `--attract-after=<s>`, `--attract-scene=<index|id>`,
`--attract-demo-s=<s>`, `--attract-press=<s>`, `--no-attract` (Abschnitt *Attract-Modus*). Video mit Ton (Godot
Movie Maker mit fester Bildrate – die Zeiten der Demo zählen Videosekunden), hier Titel → Demo → Taste → Titel:

```bash
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --write-movie /tmp/demo.avi \
  --fixed-fps 30 --quit-after 1000 res://scenes/main.tscn -- --attract-after=6 --attract-press=20
ffmpeg -i /tmp/demo.avi -c:v libx264 -pix_fmt yuv420p -crf 20 -c:a aac -b:a 192k /tmp/demo.mp4
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
`attract`: `enabled`, `idle_s` (60), `demo_s` (30), `fade_s` (Überblendung über Schwarz), `guard_s` (Schutzzeit nach
dem Aufwecken), `scenes` (Abschnitt *Attract-Modus*).
`audio`: `master_db`, `engine_db` (Pegel des Motors aus der Bank, zusätzlich zu deren `mix.gain`),
`engine_latency_s` (Vorlauf im Generator, Standard 0,07 s), `engine_buffer_s` (Puffer des Generators, 0,25 s),
`engine_preview` (Gasstoß in der Fahrzeugwahl an/aus), `engine_bank_dir` (Ordner der Motorbänke), nur für den
Rückfall ohne Bank `engine_gears`, `engine_idle_hz`, `engine_max_hz` (Motor-Grundton bei Höchstdrehzahl);
`music_db` (Pegel des Music-Busses, −9 dB für die auf −14 LUFS gemasterte Titelmelodie), `menu_music` (Menümusik
an/aus), `music_file` (Titelmelodie; fehlt sie, spielt die synthetisierte Schleife).

**Zahlen in Spielertexten** kommen aus der Konfiguration, damit sie nach dem Abstimmen (auch per
`game_config.json` neben der ausführbaren Datei) stimmen: Etappenpause `time.stage_pause_hours` und Zeitraffer
`time.time_scale` (Startzeit-Bildschirm, „Nächster Start (12 h Pause)“), Schrittweite
`time.start_hour_step_minutes` (Startzeit-Hinweise), Tankspur `fuel.lane_trigger_speed_kmh` (Optionen,
Tutorial), Abschleppen `fuel.tow_refill_fraction`/`fuel.tow_penalty_s`, Radar `radar.tolerance`, Polizei
`police.escape_speed_kmh`, Startwert des Bestenlisten-Filters `leaderboard.default_filter`.
