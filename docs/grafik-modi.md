# Grafikmodi „Arcade“ und „Modern“ – Bedienung, Auswahl, Showroom, Leistungstest

Stand v0.8.0, Bauabschnitt M1 (Paket UI1). Was der Spieler von den beiden Grafikmodi sieht und einstellt: die
Optionen in zwei Seiten, die einmalige Auswahl beim ersten Start, das Klangprofil, die Absturz-Frage auf dem Titel,
der 3D-Showroom der Fahrzeugwahl, das Ladebild, die Attract-Demos und der eingebaute Leistungstest. Die Technik
dahinter (Einstellungen, Modus-Auflösung, Renderer-Naht) steht in [ARCHITECTURE.md §15](../ARCHITECTURE.md), der
verbindliche Bauplan in [dev/v080_contract.md](dev/v080_contract.md) (§3.6, §4.1, §4.2, §4.8), die Menüs allgemein
in [ui.md](ui.md).

## Ein Schalter für Bild und Klang

- **„Grafik“** (Optionen, Seite GRAFIK, und die Auswahl beim ersten Start): `Settings.graphics_mode` =
  `"arcade"` | `"modern"`. Ohne gespeicherte Wahl ist das Spiel Arcade – so verhalten sich alle Werkzeuge, Tests und
  Starts von der Kommandozeile wie vor v0.8.0.
- **„Klang“** (Seite ALLGEMEIN): „Wie Grafik“ (`sound_profile = "auto"`, Standard), „Arcade“ oder „Modern“. „Wie
  Grafik“ folgt der *gewählten* Grafik, nie der wirksamen: Ein Rückfall auf Arcade oder ein `--graphics=` ändert den
  Klang nicht, und ein schwacher Rechner kann Arcade-Grafik mit Modern-Klang spielen.
- **„Musik im Rennen“** (Seite ALLGEMEIN, Standard An): Musik während der Fahrt – nur mit dem Klang „Modern“; mit
  dem Arcade-Klang ist die Zeile gedimmt und wird vom Fokus übersprungen (Arcade hat im Rennen keine Musik).
- Eine Änderung gilt in den Menüs sofort (Showroom, Klang), im Rennen ab dem nächsten Start einer Etappe; das
  Pausemenü hat keine Grafikoptionen. Leaderboards, Spielstand und Rekorde gelten für beide Modi gemeinsam.

`GameFlow` setzt das Klangprofil beim Start (`AudioManager.set_profile(Settings.sound())`) und bei jeder Änderung
(`Settings.sound_profile_changed`) – nie während eine Etappe läuft: Eine Änderung wartet dann auf die Menüs oder den
Start der nächsten Etappe. Neben jedem `set_music()` setzt er den Musik-Kontext des Modern-Klangs
(`set_music_context`: `title` auf Titel und Auswahl, `menu`, `race_menu` auf Etappenbildschirm, Routenwahl und
Fähre, `race` beim Start einer Etappe mit Etappe, Rennen, Wetter und „letzte Etappe“, `result` auf beiden
Ergebnisbildschirmen) und „Musik im Rennen“ (`set_race_music`). Der Arcade-Klang merkt sich den Kontext nur.

## Optionen in zwei Seiten

LB / RB wechseln die Seite (Tastatur Bild ↑ / Bild ↓, Maus: Klick auf den Reiter rechts neben dem Titel); der Fokus
springt dabei auf die erste Zeile der Seite. Gespeichert wird beim Verlassen (B / Esc / „Zurück“), vor dem
Leistungstest und beim Schließen des Fensters.

| Seite | Zeilen (von oben) | rechts |
|---|---|---|
| ALLGEMEIN | Gesamtlautstärke, Effekte, Musik, Klang, Musik im Rennen, Vibration, Spielername, Zurück | Steuerung |
| GRAFIK | Grafik, Vollbild, *Qualität im Modus Modern:* Voreinstellung, Schatten, Details, Auflösung, Kantenglättung, Effekte; Leistungstest, Zurück | Vorschau, Erklärung der Zeile, Grafikkarte, Empfehlung |

- Die Qualitätszeilen sind gedimmt und werden vom Fokus übersprungen, solange „Grafik“ auf Arcade steht.
- **Voreinstellung**: Steam Deck | Niedrig | Mittel | Hoch | Eigene (`deck`, `low`, `medium`, `high`, `custom`);
  ohne Wahl die Empfehlung für die Grafikkarte (Deck → Steam Deck, schwach/Software → Niedrig, sonst Mittel).
  Ein einzeln geänderter Wert macht daraus „Eigene“ – außer die fünf Werte gleichen wieder einer festen Stufe, dann
  gilt diese (`Settings.set_quality_value`). „Eigene“ behält die letzten eigenen Werte, auch nach einem Besuch der
  festen Stufen (`Settings.choose_preset`). Jede Änderung meldet genau ein `quality_changed`.
- **Schatten** Aus/Niedrig/Mittel/Hoch, **Details** Niedrig/Mittel/Hoch, **Auflösung** 50 … 150 % (3D-Auflösung,
  Schrift und Anzeigen bleiben scharf), **Kantenglättung** Aus/MSAA 2×/MSAA 4×, **Effekte** Aus/Einfach/Voll. Was sie
  bewirken: ARCHITECTURE.md §15.2; keine Stufe dünnt aus, was der Spieler sehen muss.
- **Vorschau**: dasselbe Straßenbild in beiden Modi (`assets/ui/gfx_preview_{arcade,modern}.webp`, siehe unten).
- **Status** unter der Erklärung: Name der Grafikkarte, Empfehlung, ein erzwungener Modus (Kommandozeile,
  Konfiguration, Absturz-Marker) und „Änderungen gelten in den Menüs sofort, im Rennen ab dem nächsten Start.“

Prüfung mit echten Pad-Ereignissen: `tests/race/check_options_tabs.gd` (10 Prüfungen, siehe unten).

## Auswahl „GRAFIK WÄHLEN“ beim ersten Start

`scripts/ui/screens/graphics_choice_screen.gd`. Erscheint einmal, vor dem Titel, wenn (`Gfx.chooser_due`, Vertrag
D32) **noch kein Modus gespeichert ist** – für neue und bestehende Spieler, niemand wird stillschweigend
umgestellt –, das Spiel **ohne jedes Argument nach `--`** gestartet wurde (jedes Werkzeug, jeder Test und
`--no-chooser` übergeben eines), **mit Bildschirm** (nicht headless) und die Konfiguration
(`graphics.force_mode`) keinen Modus erzwingt.

- Zwei Karten, Arcade und Modern, jede mit dem Vorschaubild ihres Modus und einem kurzen Text. Die für diesen
  Rechner empfohlene Karte hat den Fokus und das Abzeichen „EMPFOHLEN FÜR DIESEN RECHNER“ (Modern für Steam Deck und
  normale Grafikkarten, Arcade für Software-Grafik und schwache Grafikchips – und Arcade, wenn der Absturz-Marker
  des letzten Starts da ist). Darunter eine Warnung bei Software-Grafik, schwacher Grafik oder Absturz-Marker.
- ◀▶ wechseln die Karte (nur zwischen den beiden, ▲▼ bleiben), **ein A** (Enter, Klick) übernimmt; es gibt keinen
  Weg daran vorbei (B tut nichts). Untertitel für bestehende Spieler (Einstellungsdatei, Spielstand oder Bestenlisten
  vorhanden): „Neu in v0.8.0: der Modus „Modern““, sonst „Wie soll Crossing Europe aussehen?“.
- Die Wahl setzt `graphics_mode`, lässt „Klang“ auf „Wie Grafik“, erledigt einen Absturz-Marker und wird sofort
  gespeichert; dann folgt der Titel.

## Absturz-Frage auf dem Titel

Wurde „Modern“ beim letzten Start nicht richtig beendet (der Marker `user://modern_start.lock` war beim Start noch da,
`Settings.crash_guard`), läuft dieser Start in Arcade (`effective_graphics().reason == "crash_guard"`). Der Titel
fragt dann einmal: **„Der Modus „Modern“ wurde beim letzten Start nicht richtig beendet.“** mit „Bei Arcade bleiben“
(Fokus, auch B / Esc) und „Modern noch einmal versuchen“. „Bei Arcade bleiben“ speichert Grafik Arcade; beide
Antworten entfernen den Marker (`Settings.disarm_crash_guard()`), danach hat der Titel wieder seinen Fokus. Ist
gar kein Modus gewählt, übernimmt die Auswahl beim ersten Start diese Rolle (Warnung, Arcade empfohlen).

## Ergebnisse und Bestenlisten

Bestenlisten gelten für beide Modi gemeinsam. Jeder neue Eintrag trägt das versteckte Feld `gfx` (Modus, in dem
die Etappe gezeichnet wurde; nie angezeigt, nie ein Filter) und nach einem Rückfall `gfx_fallback` (der Grund).
Der Eintrag eines Rennens bekommt `"arcade"` oder `"modern"`, wenn alle Etappen in diesem Modus liefen, sonst
`"mixed"` (`RaceState.gfx_summary()`; der Rennstand merkt sich `gfx` jeder Etappe). Lief eine Etappe nach einem
Rückfall in Arcade, sagt eine Zeile unter dem Etappenergebnis: „Diese Etappe lief im Modus „Arcade“: „Modern“ ließ
sich auf diesem Rechner nicht starten.“ – sonst sehen die Ergebnisbildschirme aus wie bisher.

## 3D-Showroom der Fahrzeugwahl

`Showroom3D` (`scripts/ui/widgets/showroom_3d.gd`) zeigt im Modus Modern das Modell der Stufe `show` auf einem
langsam drehenden Drehteller – an derselben Stelle und mit demselben Aufruf wie das Sprite (`CarShowcase.
show_vehicle()`, `VehicleScreen` ist unverändert).

- **Nur für Sets mit `showroom: true`** im Modell-Manifest (`assets/models/manifest.json`, Sets `showroom/<auto>`);
  das entscheidet das Fahrzeugpaket nach einem A/B-Vergleich mit dem Cycles-Sprite. **Heute ist keines markiert** –
  alle Autos zeigen in Modern noch ihr Sprite. Zum Ansehen: `--showroom-force` (alle Autos mit Stufe `show`, heute
  Limousine und Kompakt) oder `--showroom-force=limousine,kompakt`; `--showroom-still` hält den Drehteller an.
- Eigene, durchsichtige 3D-Welt (`SubViewport`, `own_world_3d`, `transparent_bg`): der Menühintergrund scheint durch.
  Studio-Licht: Führungslicht von vorn links oben mit weichem Schatten auf den Drehteller, Aufhelllicht von der anderen
  Seite, zwei Kantenlichter hinter dem Auto in Magenta und Cyan, ein Studio-Himmel nur für die Spiegelungen,
  Scheinwerfer an. Der Drehteller ist dunkel glänzend mit leuchtendem Cyan-Rand (wie die 2D-Plattform), 11 °/s, und
  füllt 88 % der Breite (Größe und Lage wie die 2D-Plattform). Kamera wie die der Showroom-Sprites (11 ° über dem
  Horizont, Front rechts vorn beim Einblenden). Tonemapper AgX: Filmic und Linear ließen kräftige Lacke im Farbton
  kippen (das Goldgelb des Kompakt wurde zitronengelb).
- **Physische Pixel**: Das `SubViewport` ist so groß wie das Steuerelement mal dem Streckfaktor des Fensters (660 × 400
  bei 1280 × 720 und auf dem Steam Deck, 990 × 600 bei 1920 × 1080) – sonst würde es in großen Fenstern weich
  hochskaliert. MSAA 4× (ein einzelnes Auto).
- **Laden**: Die Dateien kommen über `ModelDB.request(…, ["show"], showroom)` im Hintergrund; bis sie da sind, bleibt
  der Platz leer (kein Sprite, das kurz aufblitzt), dann gleitet das Auto herein. Ein Modell, das sich nicht bauen
  lässt, gibt den Platz dem Sprite zurück. Materialien: `ModernMaterials.shared()`; die `ce_*`-Globalen werden auf ein
  trockenes Tageslicht-Studio gesetzt (ein Rennen bei Nacht hätte sie verstellt).
- **Umschalten**: „Grafik“ wechselt sofort (`Settings.graphics_changed`). Beim Verlassen der Fahrzeugwahl meldet sich
  der Showroom bei `ModelDB` ab (`release_all(self)`); beim Verlassen von Modern gibt `GameFlow` außerdem die
  Zwischenspeicher und die gemeinsamen Materialien frei (`ModelDB.release_all()`, `ModernMaterials.drop_shared()`).
- **Arcade lädt nichts davon**: `CarShowcase` holt das Skript erst zur Laufzeit und nur in Modern über seinen Pfad;
  keine Datei, die ein Arcade-Start lädt, nennt `Showroom3D`, `ModelDB`, `ModelFactory` oder `ModernMaterials`.

Bilder: `--screen=vehicle --sample-vehicle=limousine --graphics=modern --showroom-force --showroom-still`.

## Ladebild

`LoadingOverlay.set_progress(p)` (0 … 1): Die Rennsitzung zeigt das Ladebild „Etappe wird geladen …“ deckend, solange
ein Modern-Renderer die Etappe vorbereitet (Selbsttest, Modelle, Shader-Aufwärmen), und meldet den Fortschritt aus
`prepare_progress()`; unter dem Text erscheint dann ein Balken, der nie zurückläuft. Ohne Aufruf ist das Ladebild das
von v0.7.0 (Menüs, beide Modi).

## Attract-Demos

Die Demos laufen im wirksamen Modus (die Demo nennt keinen eigenen, die Sitzung nimmt
`Settings.effective_graphics()`). In Modern füllt das Bild das Fenster (`expand`), Arcade behält 16:9 mit Balken;
zurück im Titel stellt `GameFlow` das Seitenverhältnis der Menüs wieder her. Eine Modern-Etappe wird erst vorbereitet:
So lange bleibt das Bild schwarz, und die 30 s der Demo samt Fortschrittslinie zählen ab dem Start der Etappe
(`RaceSession.is_live()` / `stage_live`), nicht ab dem Start der Szene. Wird eine Etappe nach 90 s noch nicht live,
endet die Demo („error“). Eine Arcade-Etappe ist ab dem ersten Schritt live – an ihr ändert sich nichts.

## Leistungstest

Optionen → GRAFIK → „Leistungstest“ (oder `--bench`). Er fährt die drei festen Szenen aus `graphics.benchmark.scenes`
(Autobahn bei Tag, Stadt bei Nacht im Regen, Bergstrecke mit Tunnel) je `graphics.benchmark.seconds` (20 s) mit dem
Autopiloten und festem Verkehr im Modus Modern – mit den Qualitätseinstellungen der Seite GRAFIK und mit dem
Modern-Renderer, den der Build enthält. V-Sync und Bildbegrenzung sind während der Messung aus (und danach wieder an).

- **Ablauf**: `GameFlow.start_benchmark()` startet `ModernBenchmark` (`scripts/race3d/benchmark.gd`, zur Laufzeit
  geladen), der die Rennszene über `start_attract_stage()` zeigt (`setup.gfx = "modern"`, nichts wird gespeichert).
  Je Szene: Vorbereitung hinter dem Ladebild (nicht gemessen), 1 s Einschwingen, dann das Messfenster. Über dem
  Rennbild steht eine Leiste unter der Streckenleiste des HUD („LEISTUNGSTEST · Szene 2 von 3 · Stadt bei Nacht im
  Regen · B Abbrechen“), am unteren Rand füllt sich eine Linie. B / Esc bricht ab, ein verlorener Fensterfokus auch.
- **Messwerte je Szene**: Bilder pro Sekunde im Mittel und „1 % niedrig“, Bildzeit (95. und 99. Perzentil),
  GDScript-Zeit des Renderers (`script_ms`), Draw Calls und Dreiecke samt Schattendurchgängen (aus `perf_stats()` des
  Renderers, viermal je Sekunde abgetastet). Die langsamste Szene entscheidet über den Vorschlag
  (`Gfx.bench_suggestion`): zu langsam → eine Stufe tiefer, auf der niedrigsten weit zu langsam → Arcade, flüssig mit
  Reserve (Median ≤ Ziel / 1,5 und 99 % im Ziel) → eine Stufe höher. Ziel ist die Bildzeit der Anzeige, nie kürzer
  als 1/60 s (ein 144-Hz-Bildschirm macht 60 Bilder/s nicht „langsam“, A-2).
- **Ergebnisseite**: Tabelle der Szenen, Grafikkarte, Voreinstellung, Auflösung, V-Sync, das Urteil und „„Mittel“
  übernehmen“ bzw. „Zu Arcade wechseln“ (nicht bei einem Abbruch, beim Gerüst-Renderer oder wenn der Vorschlag schon
  eingestellt ist), „Noch einmal“, „Zurück“ (zur Seite GRAFIK, Fokus auf „Leistungstest“).
- **Datei** `user://leistungstest.json` (auf dem Steam Deck `~/.local/share/godot/app_userdata/Crossing Europe –
  A Racing Xperience/leistungstest.json`, unter Windows `%APPDATA%\Godot\app_userdata\…`; der Pfad steht auf der
  Ergebnisseite) und zusätzlich `--bench-out=<datei>`:

```json
{"version": 1, "date": "…", "adapter": "…", "api": "…", "tier": "deck", "preset": "deck",
 "quality": {"shadows": 1, "details": 1, "scale": 100, "aa": 1, "effects": 1}, "resolution": [1280, 800],
 "scenes": [{"id": "autobahn", "avg_fps": 87.4, "low1_fps": 71.2, "frame_ms_p95": 12.9, "frame_ms_p99": 14.1,
             "script_ms": 1.31, "draw_calls": 412, "primitives": 281400, …}, …],
 "suggested_preset": "deck", "suggested_mode": "modern", "verdict": "ok", …}
```

  Zusätzliche Felder: je Szene `name`, `frames`, `seconds`, `frame_ms_median`, `frame_ms_max`, `draw_calls_shadow`,
  `primitives_shadow`, `frame_draw_calls` / `frame_primitives` (ganzes Bild samt HUD), `sim_ms`, `prepare_s`,
  `video_mem_mb`; sonst `suggested_mode`, `verdict`, `worst_scene`, `headroom`, `target_ms`, `refresh_hz` (−1 =
  unbekannt), `vsync`, `seconds`, `game_version`, `os`, `cpu`, `cpu_threads`, `vendor`, `driver`, `renderer_stub`
  (der Build zeichnet Modern erst als Gerüst – die Zahlen sagen dann nichts über die fertige Grafik), `fallback`,
  `aborted`, `error`.
- **Rückfall**: Lässt sich Modern nicht starten (Selbsttest, Manifest, Renderer fehlt), endet der Test sofort mit
  `"fallback": <Grund>`, ohne Szenen und mit dem Vorschlag Arcade – und schreibt die Datei trotzdem (das *ist* das
  Ergebnis für diesen Rechner). Ein Abbruch schreibt nichts.
- **Kommandozeile**: `-- --bench=all` (oder `--bench=autobahn,berg_tunnel`), `--bench-out=<datei.json>`,
  `--bench-seconds=<s>` (Tests); das Spiel druckt `LEISTUNGSTEST {…}` und beendet sich (Exit-Code 1 ohne gemessene
  Szene). Gegen den Steam Deck und Windows ist das der Weg, Zahlen zu bekommen – auf der Bau-VM (llvmpipe) sagen sie
  nichts über eine echte Grafikkarte.

## Vorschaubilder

`tools/gfx_previews.sh` rendert dieselbe Straße aus demselben Simulationszustand – Kiel – Hamburg bei km 2 am Mittag,
trocken, fester Verkehr, Autopilot, ohne HUD – einmal in Arcade und einmal in Modern nach
`assets/ui/gfx_preview_{arcade,modern}.webp` (960 × 540, im Paket verlustbehaftet mit Mipmaps). **Nach jeder
Änderung am Aussehen von Modern neu erzeugen** – das Bild zeigt den Renderer, den der Baum gerade enthält (Stand
UI1: das Gerüst des Renderers, Himmel und graue Ebene).

```bash
XDG_DATA_HOME=/abs/ordner tools/gfx_previews.sh                 # beide Bilder nach assets/ui/
tools/gfx_previews.sh --only=modern --gfx-preset=high --km=2.0  # nur Modern
```

## Kommandozeile (Ergänzungen)

| Schalter | Wirkung |
|---|---|
| `--graphics=arcade\|modern` | erzwingt den Modus dieses Starts (stärker als alles Gespeicherte) |
| `--gfx-preset=…`, `--gfx=shadows=0,…` | Qualität dieses Starts |
| `--sound=arcade\|modern` | Klangprofil dieses Starts |
| `--no-chooser` | nie die Auswahl beim ersten Start |
| `--bench=<id,…\|all>`, `--bench-out=<datei>`, `--bench-seconds=<s>` | Leistungstest, dann Ende |
| `--screen=graphics_choice` (`--recommend=arcade\|modern`, `--existing-player=0\|1`) | Auswahl mit Beispieldaten |
| `--screen=options --options-tab=grafik` | Optionen, Seite GRAFIK |
| `--screen=benchmark` (`--bench-sample=ok\|slow\|arcade\|fallback\|stub\|abort`) | Leistungstest-Seiten |
| `--screen=title --sample-crash-guard` | Titel mit der Absturz-Frage |
| `--screen=vehicle --sample-vehicle=<id>` (`--showroom-force[=ids]`, `--showroom-still`) | Fahrzeugwahl, Showroom |
| `--screen=result --sample-gfx-fallback[=<grund>]` | Etappenergebnis mit dem Hinweis nach einem Rückfall |

## Prüfungen

| Datei | Was | Lauf |
|---|---|---|
| `tests/unit/core/test_gfx_ui.gd` | Bedingungsmatrix der Auswahl (120 Fälle), Empfehlung, Wächter gegen max(Bildzeit, 1/60 s), Statistik und Vorschlag des Leistungstests, Angebote der Ergebnisseite, Voreinstellung/Einzelwerte, Hin und Zurück jeder neuen Option (96 Kombinationen), `gfx` der Einträge | `tools/run_tests.sh` (Unit-Tests) |
| `tests/unit/ui/test_showroom.gd` | welche Sets 3D bekommen (Fixture-Manifest, erzwungene Limousine), physische Pixel, Bildausschnitt, `CarShowcase` nennt keine 3D-Klasse | Unit-Tests |
| `tests/race/check_options_tabs.gd` | 10 Prüfungen mit echten Pad-Ereignissen: Seiten mit LB/RB, Grafik, Klang folgt, übersprungene Zeilen, „Eigene“, „Musik im Rennen“, Speichern | **von Hand** (noch nicht in `run_tests.sh`): `godot --headless --path . -s res://tests/race/check_options_tabs.gd -- --graphics=arcade` |
| `tests/race3d/check_benchmark.gd` | Leistungstest mit dem Renderer des Builds: Format, Datei, `--bench-out`, Ergebnisseite, Bildbegrenzung, Rückfall, Abbruch, Szenenauswahl | Haken von `run_tests.sh` |
| `tests/race3d/check_showroom.gd` | Showroom im laufenden Spiel: Stufe show, eigene durchsichtige Welt, Sprite ohne Modell, Zwischenspeicher, Arcade gibt frei, zurück nach Modern, Abmelden | Haken |
| `tests/race3d/check_attract_modern.gd` | Demo mit langsam vorbereitendem Renderer: schwarz, Uhr steht, demo_s ab `stage_live` | Haken |
| `tests/race3d/render/check_showroom_render.gd` | Showroom auf echtem Renderer: physische Pixel bei Streckfaktor 1,0 und 1,5 (660 × 400, 990 × 600), durchsichtig, nicht angeschnitten, dreht | `tools/run_render_checks.sh modern showroom` (Xvfb) |
| `tests/race/check_attract.gd`, `check_attract_scenes.gd` | wie bisher, jetzt in beiden Modi (`-- --graphics=arcade\|modern`) | `run_tests.sh` mit Arcade; Modern **von Hand** |
