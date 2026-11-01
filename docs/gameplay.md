# Gameplay-Modul

Reine Spiellogik (keine Nodes, keine Autoloads) für Fahrzeug, Verkehr, Tanken, Radar/Polizei, Uhr und
Umwelt – umgesetzt nach dem [Design-Dokument](Design-Dokument.md) und ARCHITECTURE.md §7.
Alle Zahlen stehen in `config/game_config.json` (Abschnitte `time, daytime, vehicles, driving, collision,
traffic, fuel, radar, police, city_limits, weather`). Alles ist für einen Seed deterministisch.

| Datei | Inhalt |
|---|---|
| `scripts/gameplay/vehicle_model.gd` | `VehicleModel` – Arcade-Fahrmodell, Straßenrand, Kollision, Automatik |
| `scripts/gameplay/traffic_system.gd` | `TrafficSystem` – Verkehr (IDM-Folgefahren + MOBIL-Spurwechsel), Kollisionsabfragen |
| `scripts/gameplay/fuel_system.gd` | `FuelSystem` – Verbrauch, Ansagen, Tankspur, Tanken, Abschleppen |
| `scripts/gameplay/police_system.gd` | `PoliceSystem` – Radarwarnung/-feld, Verfolgung, Flucht, Anhalten |
| `scripts/gameplay/world_clock.gd` | `WorldClock` – Weltzeit im Zeitraffer |
| `scripts/gameplay/environment_model.gd` | `EnvironmentModel` – Tageszeit/Wetter: vmax, Haftung, Sicht, Rennwetter |
| `tests/unit/gameplay/test_*.gd` | 90 Unit-Tests: Regeln je System + Designzahlen (a)–(h) (`test_design_numbers.gd`) |
| `tests/sim/gameplay_sim.gd` | Simulationen (a)–(i), (b2), (e2), Tabellen; `tests/sim/run_sims.gd` druckt alle |
| `tests/sim/stage_sim.gd` | Etappe mit echtem `StagePlan`/`Track` und Bot-Fahrer, Kollisions-/Ereignisprotokoll |
| `tests/sim/curve_sim.gd` | Nur Kurven: echte Etappe ohne Verkehr/Radar/Tanken, Fahrer mit Bremskurve oder Vollgas – was Kurven kosten |
| `tests/sim/curve_sight.gd`, `sight_check.gd` | Sichtprüfung: reicht Bremsen ab dem Moment, in dem eine Kurve (oder ihr Warnschild) sichtbar wird? |
| `tests/sim/fake_track.gd`, `fixtures.gd` | Mini-Strecke und Hilfen für Tests (Plan aus Feldern, Tabellen) |

```bash
tools/run_tests.sh gameplay                                   # nur Gameplay-Tests (~50 s)
godot --headless --path . -s res://tests/sim/run_sims.gd      # alle Tabellen (a)–(i), -- --only=traffic|understeer …
godot --headless --path . -s res://tests/sim/stage_sim.gd -- --stage=dev_testetappe --vehicle=kompakt --hour=8 \
      [--speeding] [--weather=rain] [--fuel=12] [--start-km=40] [--verbose]
godot --headless --path . -s res://tests/sim/curve_sim.gd -- --stage=saragossa_pau [--vehicle=all|<id>] \
      [--margin=0.96] [--decel=15] [--no-brake] [--grip=7.6,8.3,9.0,9.7,10.4] [--set=driving.understeer.push_gain=3] \
      [--trace=<km von>,<km bis>] [--sections]
godot --headless --path . -s res://tests/sim/curve_sight.gd -- [--stage=<id>|all] [--vehicle=gran_turismo] \
      [--weather=snow] [--night] [--reaction=1.0] [--top-speed] [--no-signs] [--tolerance=0.05]
```

## Entscheidungen (offene Punkte des Design-Dokuments)

| Offener Punkt | Entscheidung (Konfiguration) |
|---|---|
| Wie stark senken Regen, Schnee und Nacht die Höchstgeschwindigkeit? | Regen −2,5 % (`driving.weather_vmax_factor.rain` 0,975), Schnee −12 % (0,88), Nacht −1 % (`driving.night_vmax_factor` 0,99, weich über die Dämmerung). Regen + Nacht = −3,5 %: das langsamste Auto (230) schafft 222 km/h → Flucht möglich; Schnee verhindert sie bei Kompakt/Kombi/Limousine. Haftung (sichere Kurvengeschwindigkeit ∝ √Haftung): Regen 0,88, Schnee 0,72. **Steigung**: bis `driving.grade_free_percent` (4 %) kein Verlust, darüber 1,2 % je Prozentpunkt (`grade_vmax_loss_per_percent`). „Leicht verschlechterte Bedingungen“ (Design: jedes Auto schafft dann noch 220 km/h) = Regen und/oder Nacht auf normalem Hügelland bis Hügelstufe 2 (≤ 4,5 %): Kompakt bei Regen + Nacht an 4,5 % noch 220,7 km/h, Flucht gelingt (Tabellen (e), (f)). Deutlich schlechter = Schnee oder steile Bergstrecken (Hügelstufe 3, 7 %: −3,6 %, Kompakt bei Regen + Nacht 214 km/h). |
| Länge der Zeitstrafe bei leerem Tank | `fuel.tow_penalty_s` = **90 s** Strafe + Ausrollen (18 km/h/s) + 4 s Einblendung `TOWING`, danach halber Tank (`tow_refill_fraction` 0,5). Effektiv ≈ 110 s, etwa das 2,5-Fache eines vollen Tankstopps (25 s + Bremsen/Anfahren). Wer mit leerem Tank in eine Tankspur rollt, tankt dort normal (kein Abschleppen) – ein leeres Auto in der Tankspur wird nie abgeschleppt, und Gas bricht das Tanken erst ab, wenn mindestens `fuel.abort_min_fuel_l` (1 L) im Tank sind. |
| Verhalten am Straßenrand | **Bankett** (2,5 m, `road.shoulder_width_m`): ragt die Karosserie > 0,5 m über den Fahrbahnrand, bremst der Wagen auf 90 km/h (35 km/h/s), `off_road = 1`; loser Belag: dort nur 60 % Haftung (`driving.shoulder.grip_factor`), ein untersteuernder Wagen rutscht also weiter. **Harte Grenze** am Bankettende: mit Leitplanke (Autobahn) Kontakt → Tempo × 0,9 je Treffer (höchstens alle 0,6 s), Abprallen mit 1,5 m/s nach innen, Schleifen 20 km/h/s; trifft die Untersteuer-Abdrift die Leitplanke, kostet jeder m/s über 1 m/s weitere 5 % (`driving.guardrail.impact_*`, bis Tempo × 0,5 – ungebremst seitlich hinein); ohne Leitplanke (Landstraße, Stadt) **Gras** → stark bremsen auf 40 km/h (60 km/h/s); beides `off_road = 2`, die Abdrift endet dort. |
| Wetter im Rennen | `weather.race_mode`: `region` (Standard, gewichtet nach Klima des Etappenlandes), `random` (gleichverteilt), `fixed` (Feld `weather` der Etappe, sonst Region). `EnvironmentModel.race_weather(plan, race_seed, leg_index)` ist deterministisch. |

Weitere Festlegungen:

- **Beschleunigung**: dv/dt = a0·(1 − v/vmax)^(1−q), a0 und q je Fahrzeug so gelöst, dass 0–100 und 0–200 km/h exakt
  den Zielen der Beschleunigungsstufe entsprechen; analytisch integriert (bildratenunabhängig), vmax wird in endlicher Zeit
  erreicht (q > 0). Die Kurve gilt relativ zur aktuellen Höchstgeschwindigkeit (Wetter/Nacht/Steigung). Über dem Maximum
  (z. B. bergauf) sinkt das Tempo mit 12 km/h/s darauf ab. Steigungen bis 4 % senken das Maximum nicht (siehe oben).
- **Lenken**: seitlich `steer_mps` der Agilitätsstufe, linear ab 0 bis 60 km/h hochgefahren, Ansprechzeit 0,12 s.
  Der Wagen folgt der Straße; unterhalb der sicheren Kurvengeschwindigkeit gibt es keinerlei Abdrift.
- **Kurvengrenze** (seit v0.3.0-Playtest: „Kurven gehen immer mit Top Speed“): die Kurve verlangt die Querbeschleunigung
  a = v²/R (R = `road.curve_radius_at_1_m` 120 m / |Kurve|), die Reifen geben a_Haftung = `lat_grip` der Agilitätsstufe
  × Wetterhaftung (Regen 0,88, Schnee 0,72). Sichere Kurvengeschwindigkeit v_sicher = √(a_Haftung · R).
  `lat_grip` je Agilität 1–5: **5,6 / 6,2 / 6,8 / 7,4 / 8,0 m/s²** (vorher 7,6–10,4: damit lagen fast alle
  Autobahnkurven über vmax). Ergebnis (Tabelle (i)): Kurvigkeit 1 (R ≥ 545 m) fährt der Kompakt mit Vollgas, der Gran
  Turismo muss in 61 % dieser Kurven Gas wegnehmen; Kurvigkeit 2 verlangt 146–166 km/h, Bergstraßen 104–118 km/h.
- **Untersteuern** (kein Übersteuern, kein Dreher): über der Grenze treibt der Überschuss a_ex = v²/R − a_Haftung eine
  Abdrift nach außen an – als **Beschleunigung** (`push_speed` += `push_gain` 2,5 · a_ex · dt), sie baut sich also auf,
  solange der Wagen zu schnell ist. Lenken zur Kurveninnenseite behält max(0,15; 1 − 3 · a_ex/a_Haftung) seiner Wirkung
  (gesättigte Vorderreifen: knapp zu schnell hilft Gegenlenken, deutlich zu schnell nicht), Lenken nach außen wirkt voll.
  Die rutschenden Reifen radieren min(0,5 · a_ex; 3 m/s²) vom Tempo. Unter der Grenze klingt die Drift mit
  `recover_s` 0,25 s ab. Je Schritt exakt integriert (a_ex konstant im Schritt) – bildratenunabhängig.
  `understeer` (0..1, HUD „UNTERSTEUERN“ ab 0,3, Reifenquietschen ab 0,15) = (a_ex/a_Haftung) / `full_excess` 0,5:
  4 % zu schnell ≈ 0,16, 7 % ≈ 0,3, 22 % = 1. **Abhilfe: Gas weg oder bremsen.** Gefühlsziele, alle erfüllt
  (Tabelle (i2)): 5 % zu schnell → Gegenlenken hält die Linie; 15 % → trotz vollem Gegenlenken nach 1,4–1,5 s eine
  Spur weiter außen; 30 % → aus der Mittelspur in 1,0–1,1 s auf dem Bankett, 1,2–1,3 s an der Leitplanke.
- **Wer nicht bremst, verliert**: Im ersten Entwurf (ohne geringere Bankett-Haftung und Aufprallverlust) war
  Durchrutschen schneller als Bremsen – Leitplanke, Bankett und Radieren bremsten „gratis“ erst in der Kurve. Jetzt kostet Vollgas durch alle Kurven gegenüber gutem
  Bremsen 7–26 s je Etappe (Tabelle (i4)), mit Verkehr kommt das Unfallrisiko beim Abdriften dazu.
- **Kollision**: Tempo v(t) = 10 + (v0 − 10)·(1 − t/3 s)², also am Anfang die stärkste Verzögerung; Schub 3 m
  (ease-out) bis zum Endpunkt 0,5 s nach Erreichen von 10 km/h; erst dann wieder Gas. Unverwundbar und blinkend vom
  Treffer bis 0,75 s nach dem Endpunkt (`invulnerable_grace_s`: „Kollisionen zählen erst nach dem Wiederanfahren“).
  Richtung: weg von der Seite des getroffenen Autos; mittig (|dx| ≤ 0,25 · Breite) zur Seite mit mehr Platz,
  bei gleichem Platz (±0,25 m) nach links. Hitbox 95 % der Fahrzeugmaße. Der Platz kommt aus
  `TrafficSystem.space_beside` (Fahrbahn + Bankett und Autos **neben** dem Spieler): das getroffene Auto (`exclude`)
  und jedes Auto, dessen Karosserie die Mittellinie des Spielers überdeckt (genau vor/hinter ihm), zählen nicht –
  sonst sperrte das getroffene Auto die Seite, auf der seine Mitte zufällig ein paar Zentimeter liegt. Auffahren in
  der rechten Spur → links, in der linken → rechts, in der Mitte (gleich viel Platz) → links (Test
  `test_centre_hit_pushes_to_side_with_more_space`, auch im echten Rennszenen-Lauf geprüft).
- **Automatik** (`auto_control`): Tempo wird geregelt, Gas/Bremse ignoriert; ohne `steer_x` lenkt der Spieler weiter
  (Rechts ranfahren, Ausrollen), mit `steer_x` lenkt die Automatik.
- **Tanken**: Auslösung in der Tankspur unter 60 km/h, wenn ≥ 1 L fehlt. Erst 5 s fester Anteil (Anhalten,
  Zapfpistole), dann fließen 2,5 L/s. Abbruch nur durch einen **frischen** Gasstoß (Pedal muss seit Tankbeginn einmal
  losgelassen worden sein); die bis dahin getankten Liter bleiben. Mit (fast) leerem Tank – weniger als
  `fuel.abort_min_fuel_l` (1 L) – ist „Weiterfahren“ unmöglich: der Gasstoß wird ignoriert (`can_abort_refuel()`
  false; HUD-Hinweis z. B. „Tank leer – bitte warten“), nach 5,4 s ist 1 L drin. Danach neues Tanken erst wieder nach
  > 60 km/h oder Verlassen der Spur – außer der Tank ist leer: ein leeres Auto in der Tankspur tankt immer und wird
  nie an der Zapfsäule abgeschleppt. `ran_dry` kommt einmal je leerem Tank, `tow_started` erst, wenn wirklich
  abgeschleppt wird (Wagen steht außerhalb einer Tankspur). Ansagen 30/15/5 km je Tankstelle einmal; mehrere
  gleichzeitig überquerte Schwellen → nur die nächste; bei Start mitten in der Etappe werden längst überfahrene
  Schwellen still übersprungen (nie eine falsche Entfernung).
- **Radar**: Warnung einmal bei `warn_km`; Auslösen ab limit · 1,15 (120 → 138,0 km/h, „ab“ = ≥) irgendwo im Feld,
  jedes Radar höchstens einmal, nie während Verfolgung/Anhalten.
- **Verfolgung**: Polizeiwagen startet 320 m (sichtbare Meter) hinter dem Spieler und fährt 220 km/h; der Abstand
  ändert sich mit (v − 220)/3,6 m/s. Flucht, wenn der zeitgewichtete gleitende Durchschnitt der letzten 12 s
  ≥ 220 km/h ist und die Verfolgung mindestens 12 s lief. Erwischt bei Abstand 0 oder nach 60 s →
  `STOPPING` (40 km/h/s auf 0, Signal `pull_over`) → `STOPPED` 10 s (Signal `caught` = „Führerschein, bitte!“
  genau für die Standzeit) → `released`. `escape_progress` = min(t/12 s, 1) · clamp((Ø − 160)/60, 0, 1).
  - **Zeitlimit** `police.catch_timeout_s` = 60 s (nicht im Design, verhindert endlose Verfolgungen knapp unter
    220 km/h). Es ist so lang, dass die Design-Regel „Eine Verfolgung kann in die City Limits hineinlaufen“ im Spiel
    vorkommt: Radarfelder enden ≥ 30 km vor den City Limits (Feldanfang ≥ 35 km); wer dort geblitzt wird und mit
    200–219 km/h zu fliehen versucht, wird erst in den City Limits gestellt (Tabelle (e2): Würzburg – Kassel
    3–9 km in den City Limits). Mit 40 s war das auf keiner Etappe möglich (max. ≈ 29 km Verfolgung).
  - **Blockiert** (`set_blocked(true)`, die Rennsitzung übergibt jeden Schritt vor `update`, ob das Tanksystem den
    Wagen hält – `FuelSystem.holds_car()`, also Tanken oder Abschleppen): `STOPPING` wird nicht zu `STOPPED`,
    `STOPPED` zählt nicht herunter. Ein Zugriff während des Tankens wird danach abgesessen, in beiden Reihenfolgen
    (erst Tanken, dann erwischt / erst erwischt, dann in der Tankspur unter 60 km/h): Stand = Tanken + volle 10 s
    (Tabelle (b2)). Vorher kostete ein Zugriff an der Tankstelle praktisch nichts.
  - **Darstellung** (`police_car_offset_m()`): während der Verfolgung −Abstand, aber nie näher als
    `police.overtake_from_m` (16 m, hinter der Kamera bei 9 m) – der Wagen ist nie halb im Bild. Beim Zugriff
    überholt er in `police.overtake_s` (2,2 s, smoothstep) von −16 m bis `pull_over_offset_m` (+12 m) und bleibt dort;
    das Renn-Modul zeichnet ihn dabei eine Spur neben dem Spieler (Seite festgelegt, solange er außer Sicht ist) und
    schert danach ein – kein Auftauchen aus dem Nichts mehr. `overtaking()`/`overtake_time` für Effekte.
- **Verkehr**:
  - Wunschtempo je Auto = fester Anteil im Bereich des Straßentyps × 1,15 von 23 bis 4 Uhr; Straßentypwechsel
    (Autobahn → Landstraße → City) übernimmt jedes Auto sofort als neues Wunschtempo. Lkw/Busse fahren am langsamen
    Ende **desselben** Design-Bereichs (`truck_speeds_kmh`: Autobahn 110–120, Landstraße 70–80, City 40–50 km/h) –
    die Grundgeschwindigkeit des Designs gilt für alle Fahrzeuge (Test `test_truck_speeds_inside_design_ranges`).
  - Folgefahren: Intelligent Driver Model (a = 1,6 m/s², Lkw 0,7; komfortabel 2,5, max. 8 m/s²; Mindestabstand 14 m +
    1,2 s). Bremslicht ab 0,6 m/s² Verzögerung und im Stand.
  - Spurwechsel: MOBIL (Vorteil > 0,2 m/s², Lkw nach links > 0,6; Sicherheit: neuer Hintermann muss nicht stärker als
    3 m/s² bremsen; Höflichkeit 0,3; Rechtsfahrgebot +0,3 m/s² auf Autobahn/Landstraße). Lkw nie auf die linke Spur
    einer dreispurigen Straße. Endet eine Spur (Vorausschau 60 m + 6 s), wird zwingend eingefädelt; ohne Lücke hält
    das Auto vor dem Spurende an.
  - **Keine rollenden Straßensperren** (vorher fuhren zwei Autos mit 74/75 km/h minutenlang nebeneinander und
    sperrten eine Landstraße; Elefantenrennen bei Lkw ebenso). Ein Auto auf einer linken Spur prüft die
    Verkehrsautos auf der Spur rechts (70 m dahinter bis 40 m davor, `side_window_*`), die es nicht ohnehin um
    mindestens `yield_speed_margin_kmh` (6 km/h) überholt:
    - **zügig überholen**, wenn sie höchstens 6 km/h schneller sind, als es fahren will, und es innerhalb seines
      Tempobereichs klar schneller sein kann: Wunschtempo + `pass_boost_kmh` (10 km/h), höchstens oberes Ende des
      Design-Bereichs (× Nachtfaktor); danach ordnet es sich rechts ein. 74 neben 75 km/h → überholt mit 85 km/h;
    - sonst (ein klar schnelleres Auto kommt rechts auf, oder es kann nicht klar schneller sein, z. B. Lkw auf
      der Landstraße) **zurückfallen**: auf deren Tempo − `yield_slowdown_kmh` (15 km/h, nie über dem eigenen
      Wunschtempo), dahinter rechts einordnen (Rechtsfahrgebot + `yield_keep_right_bonus_mps2` 1,0 m/s², dabei
      kein Ausweichen nach links). Kein Wettrennen mit einem schnelleren Auto, das rechts vorbei will.
    Der Spieler zählt nie (er regelt sein Tempo selbst – ein Auto, das sich nach ihm richtet, bliebe neben ihm
    und sperrte ihm die Überholspur). Neue Autos erscheinen nicht dort, wo sie sofort zurückfallen müssten.
    Ergebnis: längstes Nebeneinander gleich schneller Autos in den Landstraßen-Simulationen ≤ 0,6 s (ohne die
    Regeln 17–41 s), Testfall 74/75 km/h ≈ 2 s; Spuranteile und Spurwechsel wie ohne die Regeln.
  - Spieler: zählt als Hindernis in jeder Spur, in die seine Karosserie ragt. Autos bremsen hinter ihm (IDM) und
    überholen links (oder rechts, wenn er sie bedrängt). In allen Simulationen fuhr kein Auto in den Spieler.
  - Tankspur: Ein Auto entscheidet 420 m vor einer Tankspur mit `fuel_lane_use_chance` (0,12), sie zu nutzen, wechselt
    nach rechts, bremst rechtzeitig auf 50 km/h, fährt die Spur entlang und fädelt vor ihrem Ende wieder ein.
  - Dichte: Ziel-Anzahl = ∫ Dichte über das Fenster [Spieler − 220 m, Spieler + 950 m]; gehalten wird
    floor(Ziel + Zufall), der Zufall wird alle 8 s neu gezogen (im Mittel genau das Ziel, auch bei 0,4 Autos).
  - Erscheinen nur außer Sicht: vorn hinter der Sichtweite (≥ 950 m), hinten hinter der Kamera und nur Autos, die
    schneller als der Spieler sind (Überholer, in Spuren ohne Spieler). Entfernen nur außer Sicht: > 220 m hinter dem
    Spieler, > 1200 m vorn, bei Überzahl hinter der Kamera oder tief im Nebel (> 85 % der Sichtweite).
    **Verfolgungsbeginn**: im Bild des Radarblitzes (Vollbild-Weiß) verschwinden überzählige Autos > 250 m vor der
    Kamera sofort (`traffic.chase_flash_cull_m`, 0 = aus) – so wirkt das −80 % sofort, ohne sichtbares Verschwinden.
  - Größen der Fahrzeuge: per `set_dimensions(SpriteDB.sets)` aus dem Manifest, sonst aus der Set-ID geschätzt.
  - Leistung: die Streckengeometrie wird alle 4 m einmal abgefragt und zwischengespeichert; ≈ 0,45 ms je Bild für
    15 Autos (gemessen auf der Dev-Etappe).

## Ergänzungen zur API (ARCHITECTURE.md §7 bleibt unverändert gültig)

- `VehicleModel`: Felder `lat_speed, push_speed, on_grass, rail_contact, rail_hit, crash_dir, crash_time, grace_left,
  accel_a0, accel_q`; Methoden `reset()`, `push_direction(dx, space_left, space_right)`, `accelerate(v, vtop, t)`,
  `time_to_speed(v_from, v_to, vtop = vmax)`; statisch `fit_accel_curve(vmax, t100, t200) -> Vector2(a0, q)`,
  `curve_time()`, `curve_speed()`, `top_speed_time()`. `resolve_spec()` liefert zusätzlich `accel_a0, accel_q,
  top_speed_time_s`. `off_road == 2` heißt jetzt „harte Grenze“ (Leitplankenkontakt **oder** Gras).
  `max_speed(grade, factor)`: Steigungen bis `driving.grade_free_percent` ohne Verlust.
  Untersteuern (v0.3.x): `push_speed` ist jetzt der Zustand der Abdrift (m/s relativ zur Straße, + = rechts; baut sich
  über der Grenze auf, klingt darunter ab), neu `lat_excess` (fehlende Querbeschleunigung m/s², 0 unter der Grenze),
  `rail_impact` (Abdrift beim letzten Leitplankentreffer, m/s); Methoden `grip_accel(grip)` (Haftung m/s²),
  `lateral_excess(curve, grip, speed_kmh)`, `rail_hit_factor(drift_mps)`. `safe_curve_speed()` unverändert (Formel).
- `TrafficSystem`: `set_dimensions(dims)`, `density_per_km_at(z, hour, chase)`, `is_night_hour(hour)`,
  `wanted_count()`, Felder `target_count, spawned_total, despawned_total, player_obstacle`; `ctx.visibility_m`
  (optional, Standard `render.draw_distance_m`); `update(0.0, …)` erzeugt nur den Anfangsverkehr.
  `space_beside(z, x, half_len, left, right, exclude: Object = null)`: `exclude` = das getroffene Auto; Autos in
  Linie (Karosserie überdeckt x) zählen nie. `Car` zusätzlich: `speed_frac, accel, fuel_state, from_behind, age,
  yield_kmh, pass_kmh` (Zurückfallen bzw. zügiges Überholen gegen rollende Sperren, −1 = nein) (+ interne
  Zwischenspeicher).
- `FuelSystem`: Signale `reserve_reached`, `tow_started` (echtes Abschleppen, Beginn `TOWING`); Felder
  `refuel_duration, refuel_elapsed, liters_needed, pumping, rolling_out, tow_time_left, odometer_km, liters_used,
  low_fuel`; `refuel_duration_for(liters)`, `can_abort_refuel()` (ein frischer Gasstoß bricht ab – false bei
  < `fuel.abort_min_fuel_l` im Tank), `holds_car()` (Tanken oder Abschleppen hält den Wagen → `police.set_blocked`).
- `PoliceSystem`: Signal `pull_over` (Zugriff, Beginn `STOPPING`); `caught` kommt im Stand (Beginn `STOPPED`);
  Felder `chase_radar, flashes, chases, escapes, stops, blocked, overtake_time`; `trigger_speed(limit)`,
  `siren_level()` (0..1), `set_blocked(bool)` (Polizeistopp wartet, solange ein anderes System den Wagen hält),
  `overtaking()` (Überholanimation läuft); `police_car_offset_m()` ist beim Zugriff animiert (s. o.).
- `WorldClock`: `start_world_minutes`, `elapsed_world_minutes()`, `elapsed_game_seconds()`,
  statisch `world_minutes_at(day, hour)`.
- `EnvironmentModel`: `pick_weather(seed, climate, hint = "")` (Rennmodus), `race_weather(plan, race_seed,
  leg_index = 0)`, `weather_types()`.

## Zahlen (Simulationen, 60 Hz, echte Klassen – `tests/sim/run_sims.gd`)

**(h) Beschleunigung** (Ziel ±10 %, erreicht: < 0,5 % Abweichung)

| Fahrzeug | vmax | 0–100 s (Ziel) | 0–200 s (Ziel) | 0–vmax s | a0 km/h/s | q |
|---|---|---|---|---|---|---|
| Kompakt | 230 | 4,60 (4,6) | 12,02 (12,0) | 19,3 | 25,0 | 0,477 |
| Kombi | 235 | 7,02 (7,0) | 19,02 (19,0) | 36,7 | 16,8 | 0,378 |
| Limousine | 245 | 5,60 (5,6) | 14,50 (14,5) | 28,8 | 20,7 | 0,409 |
| Sportwagen | 255 | 3,80 (3,8) | 10,00 (10,0) | 25,2 | 30,9 | 0,322 |
| Gran Turismo | 270 | 4,62 (4,6) | 12,02 (12,0) | 38,7 | 25,6 | 0,263 |

**(a) Kollision bei 200 km/h** – Zeitverlust gegenüber Weiterfahren mit 200 (Ziel 7–10 s; Pflicht für Beschleunigung 3):
10 km/h nach 3,00 s, Endpunkt 3,5 s, Schub 3,0 m.

| Kompakt (4) | Kombi (2) | **Limousine (3)** | Sportwagen (5) | Gran Turismo (4) |
|---|---|---|---|---|
| 7,0 s | 9,6 s | **8,0 s** | 6,2 s | 7,0 s |

**(b) Von der Polizei erwischt** – Verlust ab dem Zugriff (Bremsen 40 km/h/s, 10 s Stehen, Anfahren aus dem Stand),
Ziel 15–20 s. Referenz 160–180 km/h (typisch geblitzt im 120er-Feld, ohne Fluchtversuch): alle Fahrzeuge im Ziel.

| Tempo | Kompakt | Kombi | Limousine | Sportwagen | Gran Turismo |
|---|---|---|---|---|---|
| 140 | 14,9 | 16,6 | 15,6 | 14,4 | 14,9 |
| **160** | **15,7** | **17,7** | **16,6** | **15,1** | **15,7** |
| **180** | **16,6** | **18,9** | **17,5** | **15,8** | **16,6** |
| 200 | 17,5 | 20,2 | 18,6 | 16,7 | 17,5 |

Bei 160 km/h dauert es 19,2 s, bis die Polizei aufgeholt hat (320 m bei 60 km/h Differenz).

**(b2) Erwischt an der Tankstelle** (Limousine, ~42 L, `police_refuel_run`, Rennsitzungs-Reihenfolge mit
`set_blocked(fuel.holds_car())`): Stand 20,8 s nur Tanken; erst Tanken, dann Zugriff 30,8 s; erst Zugriff, dann
unter 60 km/h in der Tankspur 30,9 s – der Polizeistopp kommt immer mit vollen 10,0 s hinzu, „Führerschein, bitte!“
erst nach dem Tanken (vorher: 0 s zusätzlich).

**(c) Tankdauer** = 5 s + 2 s je 5 L: leerer 50-L-Tank **25,0 s** (gemessen 25,00); voll aus leer: Kompakt 23 s,
Kombi 33 s, Limousine/Gran Turismo 29 s, Sportwagen 27 s; halber 50-L-Tank 15 s.

**(d) Verbrauch** (L/100 km) = 14 + 0,00034 v² (Integration über `FuelSystem.update` identisch)

| km/h | L/100 km | Reichweite 50 L | Design-Dokument |
|---|---|---|---|
| 100 | 17,40 | 287 km | 17,4 L / ca. 290 km |
| 130 | 19,75 | 253 km | 19,7 L / ca. 255 km |
| 180 | 25,02 | 200 km | 25,0 L / ca. 200 km |
| 250 | 35,25 | 142 km | 35,3 L / ca. 140 km |

Reichweite je Fahrzeug (voller Tank): Kompakt 45 L × 0,85 → 268/212/150 km bei 130/180/250; Kombi 70 L × 1,0 →
355/280/199; Limousine 60 L → 304/240/170; Sportwagen 55 L × 1,15 → 242/191/136; Gran Turismo 60 L × 1,3 →
234/184/131 (bei vmax 166/214/174/132/119 km).

**(e) Flucht** (Limousine, nach dem Blitzer Tempo halten): 200 km/h → erwischt nach 57,5 s (Abstand 0), 210/219 km/h
→ erwischt nach 60 s (Zeitlimit; Abstand bleibt 153/303 m); **222 km/h → entkommen nach 12,0 s**, 230 → 12,0 s.
Vollgas ab 140 km/h bei Regen in der Nacht: alle fünf entkommen (Kompakt 18,4 s, Kombi 22,3 s, Limousine 16,8 s,
Sportwagen 13,8 s, Gran Turismo 14,5 s; kleinster Abstand 192 m) – auch bergauf mit 4,5 % (Hügelstufe 2: 19,8 /
22,9 / 17,0 / 13,9 / 14,6 s).

**(e2) Verfolgung in die City Limits** (echte Daten: das Radar am nächsten vor den City Limits, Würzburg – Kassel,
Feld km 155–160, City Limits ab km 190; Kompakt, geblitzt am Feldanfang, hält das Tempo): 190 km/h → erwischt bei
km 179,3; 200 → bei km 193,3 (3,3 km in den City Limits); 210 → km 197,0 (7,0 km); 219 → km 198,8 (8,8 km).
Im Netz beginnen 13 von 213 Radarfeldern ≤ 42 km vor den City Limits (bei 210 km/h erreichbar).

**(f) Regen + Nacht** (Faktor 0,975 · 0,99 = 0,965): Kompakt 222,0 km/h (0–220 in 16,7 s), Kombi 226,8 (26,2 s),
Limousine 236,5 (18,6 s), Sportwagen 246,1 (12,8 s), Gran Turismo 260,6 (15,0 s) – alle ≥ 220, auch an 4,5 %
Steigung (Hügelstufe 2: 220,7 / 225,5 / 235,1 / 244,7 / 259,1). Hügelstufe 3 (7 %): trocken 221,7 / 226,5 / 236,2 /
245,8 / 260,3, bei Regen + Nacht 214,0 / 218,7 / 228,0 / 237,3 / 251,2. Schnee am Tag: 202 / 207 / 216 / 224 / 238 km/h.
Echte Etappe (`run_stage.gd`, Dev-Etappe, Kompakt, 23 Uhr, Regen, Raser-Autopilot): 222,0 km/h an 2,3 % Steigung
(vorher 215,9), Radar-Verfolgung entkommen.

**(g) Verkehr** (Autobahn-Grunddichte 14 Fz/km, Landstraße 9, Stadt 8; Tageskurve `traffic.hourly_density`)

| Größe | Wert |
|---|---|
| Dichte 08:00 / 03:00 | 14,0 / 1,68 Fz/km (03:00 = 12 % von 08:00); 12:00 9,8; 17:30 13,9; 23:30 3,4 |
| Nacht 23–4 Uhr | jedes Auto +15 % (gemessen 1,150; Ø Wunschtempo neuer Autos 129,1 → 147,8 km/h) |
| Lkw/Busse | Wunschtempo im Design-Bereich: Autobahn ≥ 110,4 km/h (vorher 80–90), Landstraße 70–80, City 40–50 |
| Verfolgung | Dichte × 0,20 (−80 %); sichtbare Autos 8,1 → 2,1 (15 s nach Beginn, Spieler 225 km/h) |
| City Limits | × 2,5 gegenüber der Stadtstraße (14 Fz/km um 12:00 auf 2 Spuren = 2,1 × so viel je Spur wie Autobahn) |
| sichtbare Autos (Spieler 160 km/h) | 08:00 12,9 · 03:00 2,0 · City (80 km/h) 12,4 |
| Rollende Sperren | Landstraße 17:00, Spieler 90 km/h, 120 s: längstes Nebeneinander gleich schneller Autos 0 s (ohne die Regeln 41 s) |
| Sicherheit | 0 Überlappungen, 0 Autos tauchen im Bild auf/verschwinden, stehender Spieler: 0 Treffer bei 41 Autos |
| Spurwechsel | 11 in 60 s (12:00; vorher 35 – Pkw mussten ständig 80–90 km/h langsame Lkw überholen) |

**(i) Kurven und Untersteuern** (`run_sims.gd -- --only=understeer`, `curve_sim.gd`, `curve_sight.gd`)

Sichere Kurvengeschwindigkeit (km/h) an der schärfsten / mittleren Kurve je Kurvigkeit (`road.curviness_max_curve`
0,22 / 0,45 / 0,9 = R 545 / 267 / 133 m; Kurvenstärke gleichverteilt 35–100 % davon), in Klammern vor der Änderung,
und Anteil der Kurven, für die das Auto bei vmax Gas wegnehmen oder bremsen muss:

| Fahrzeug | Agilität | Haftung m/s² | vmax | Kurvigkeit 1 | Anteil | Kurvigkeit 2 | Anteil | Kurvigkeit 3 | Anteil |
|---|---|---|---|---|---|---|---|---|---|
| Kompakt | 5 | 8,0 (10,4) | 230 | 238 / 289 (271) | 0 % | 166 / 202 (190) | 73 % | 118 / 143 (134) | 100 % |
| Kombi | 3 | 6,8 (9,0) | 235 | 219 / 267 (252) | 20 % | 153 / 187 (176) | 88 % | 108 / 132 (125) | 100 % |
| Limousine | 3 | 6,8 (9,0) | 245 | 219 / 267 (252) | 31 % | 153 / 187 (176) | 94 % | 108 / 132 (125) | 100 % |
| Sportwagen | 4 | 7,4 (9,7) | 255 | 229 / 278 (262) | 30 % | 160 / 195 (183) | 93 % | 113 / 138 (129) | 100 % |
| Gran Turismo | 2 | 6,2 (8,3) | 270 | 209 / 255 (242) | 61 % | 146 / 178 (169) | 100 % | 104 / 126 (120) | 100 % |

Regen × 0,938, Schnee × 0,849 (√Haftung): z. B. schärfste Kurve Kurvigkeit 2 bei Schnee 124 (GT) – 141 km/h (Kompakt).
Begründung der Werte: Mit den vorgeschlagenen 5,6–8,0 m/s² bestimmt die Agilität sichtbar das Kurventempo (Spanne
14 % zwischen Agilität 2 und 5), die häufigste Straße (Autobahn Kurvigkeit 1, 6 500 km im Netz) bleibt für
Kompakt/Kombi fast und für Limousine/Sportwagen größtenteils Vollgas, der Gran Turismo zahlt dort für seine 270 km/h.

(i2) Gefühl: mit Vollgas (vmax, Gas hält das Tempo) in eine Rechtskurve, die X % zu schnell ist, aus der Mittelspur einer
dreispurigen Autobahn; Zeit in s bis eine Spur weiter außen / Bankett / Leitplanke, ohne Lenken und mit vollem
Gegenlenken (Limousine; Kompakt rutscht wegen der höheren Haftung je % etwas schneller, der GT etwas langsamer):

| zu schnell | sicher | Spur (frei) | Bankett (frei) | Spur (gegen) | Bankett (gegen) | Leitplanke (gegen) |
|---|---|---|---|---|---|---|
| 5 % | 233 km/h | 2,13 | 2,52 | – (Linie gehalten) | – | – |
| 10 % | 223 km/h | 1,48 | 1,75 | 2,90 | – | – |
| 15 % | 213 km/h | 1,20 | 1,42 | **1,45** | 1,67 | 1,92 |
| 20 % | 204 km/h | 1,03 | 1,22 | 1,20 | 1,40 | 1,60 |
| 30 % | 188 km/h | 0,82 | 0,97 | 0,93 | **1,08** | **1,25** |

Kompakt / Gran Turismo bei 15 % mit Gegenlenken: eine Spur nach 1,37 / 1,50 s; bei 30 % Leitplanke nach 1,17 / 1,30 s.
(i3) Erholung (Limousine, 0,6 s zu schnell mit Gegenlenken, dann Vollbremsung): 15 % → nach 0,43 s Bremsen unter der
Grenze, Drift nach weiteren 0,57 s unter 10 %, danach nur noch 0,22 m nach außen, bleibt in der Nachbarspur; 30 % → die
Drift (11,5 m/s) trägt den Wagen noch bis an die Leitplanke.

(i4) Was die Kurven kosten – nur Kurven (`curve_sim.gd`: echte Etappe, ohne Verkehr, Radar, Tanken; Zeit in s).
„vorher Vollgas“ = altes Modell, Vollgas mit Spurhalten (das war vor der Änderung möglich, der Spieltest-Befund);
„Autopilot“ = Bremskurve auf 96 % (wie `Autopilot`); „gut“ = bremst spät mit 18 m/s² auf 103 % (leichtes
Untersteuern, Gegenlenken hält); „Vollgas“ = neues Modell ohne Bremsen (Spurhalten = Gegenlenken):

| Etappe | Fahrzeug | vorher Vollgas | Autopilot | gut | Verlust gut ggü. vorher | Vollgas | Vollgas ggü. gut |
|---|---|---|---|---|---|---|---|
| Kassel – Würzburg (Kurvigkeit 1–2) | Kompakt | 280,6 | 292,8 | 288,0 | +7,4 (+2,6 %) | 303,1 | +15,1 |
| | Kombi | 278,9 | 304,4 | 297,3 | +18,4 (+6,6 %) | 321,9 | +24,6 |
| | Limousine | 266,5 | 294,0 | 286,2 | +19,7 (+7,4 %) | 305,8 | +19,6 |
| | Sportwagen | 254,1 | 279,0 | 271,9 | +17,8 (+7,0 %) | 287,2 | +15,3 |
| | Gran Turismo | 247,1 | 288,7 | 278,8 | +31,7 (+12,8 %) | 304,7 | +25,9 |
| San Sebastián – Burgos (0–3) | Kompakt | 304,0 | 332,7 | 327,3 | +23,3 (+7,6 %) | 344,2 | +16,9 |
| | Kombi | 308,1 | 349,0 | 342,0 | +33,9 (+11,0 %) | 361,3 | +19,3 |
| | Limousine | 294,9 | 337,0 | 329,6 | +34,7 (+11,8 %) | 351,5 | +21,9 |
| | Sportwagen | 280,1 | 319,3 | 312,1 | +32,0 (+11,4 %) | 323,5 | +11,4 |
| | Gran Turismo | 277,4 | 328,9 | 321,3 | +43,9 (+15,8 %) | 336,9 | +15,6 |
| Saragossa – Pau (1–3, Landstraße) | Kompakt | 352,7 | 399,3 | 389,5 | +36,8 (+10,5 %) | 396,3 | +6,8 |
| | Kombi | 361,4 | 426,3 | 411,7 | +50,3 (+13,9 %) | 423,1 | +11,4 |
| | Limousine | 347,0 | 413,6 | 398,7 | +51,7 (+14,9 %) | 420,5 | +21,8 |
| | Sportwagen | 329,0 | 391,0 | 377,3 | +48,3 (+14,7 %) | 390,6 | +13,3 |
| | Gran Turismo | 332,2 | 413,6 | 401,6 | +69,4 (+20,9 %) | 414,8 | +13,2 |

Vollgas: 4–15 s auf dem Bankett, 8–21 Leitplankentreffer bzw. Gras je Etappe. Der Autopilot untersteuert nie
(`understeer` max 0,00) und verlässt nie die Fahrbahn. Auf kurvigen Etappen ist jetzt der Sportwagen (Agilität 4,
Beschleunigung 5) am schnellsten, der Gran Turismo verliert am meisten.

Ganze Etappen mit Verkehr, Radar (befolgt) und Tanken (`run_stage.gd`, Autopilot bis vmax, 08:00): Zeitverlust im Mittel
+19 s je Etappe (≈ +4 %, Streuung durch Verkehr und Tankentscheidungen −25 … +60 s). Ganze Rennen (`run_race.gd`,
Limousine, Autopilot mit 235 km/h, Rennwetter und Tageszeiten je Lauf verschieden): Kiel – Nürnberg 25:20,8 → 26:08,7,
Königsrennen (33 Etappen) 5:04:10,6 → 5:03:06,4 – beide fehlerfrei; mit 235 km/h kommt der Autopilot auf
Kurvigkeit 1 kaum an die Grenze, der Unterschied geht im Rauschen unter (die Kurven kosten vor allem bei vmax, (i4)).
Bestenlisten: Die Starteinträge (`leaderboard.seed_avg_kmh` 125–165 km/h) bleiben schlagbar – der vorsichtige
Autopilot fährt im Königsrennen je nach Tageszeit 100–196 km/h Schnitt (Median 148), nachts über dem besten
Starteintrag; nur die kurze Tutorial-Etappe mit Pflicht-Tankstopp liegt wie vorher darunter. Keine Anpassung nötig.

(i5) Sichtprüfung (`curve_sight.gd`, alle 52 Etappen in beiden Richtungen): Reicht es, ab dem Moment zu bremsen, in
dem die Kurve – oder ihr Warnschild – zu sehen ist (Nebel/Nacht-Sichtweite, Kuppen: Sichtlinie aus der Kamera 3,4 m
über der Straße, 9 m hinter dem Auto), mit 1 s Reaktionszeit und Vollbremsung (70 km/h/s), um höchstens 5 % über der
sicheren Geschwindigkeit anzukommen (dort hält Gegenlenken die Linie)? Anfahrt: Vollgas aus der vorigen Kurve bis vmax.

| Fall | ohne Schilder | mit Schildern |
|---|---|---|
| Gran Turismo, Tag (Sicht 900 m) | 24 von 104 Etappenrichtungen zu knapp (bis −50 m) | **0** (kleinste Reserve +8 m) |
| Gran Turismo, Regen + Nacht (322 m) | – | 1 (−3 m, Kassel – Dortmund) |
| Gran Turismo, Schnee + Nacht (248 m) | – | **0** (+12 m) |
| Kompakt, Tag | – | **0** |

Ohne Schilder waren Kurven direkt hinter Kuppen die Falle (die Straße dahinter ist verdeckt, z. B. 153-km/h-Kurve
erst 84 m vorher sichtbar). Daher stehen jetzt Warnschilder vor scharfen **und vor blinden** Kurven (renn-modul.md §4).

## Hinweise für andere Module

- **Renn-Modul** (`race_session.gd`): (1) einmal `traffic.update(0.0, player, ctx)` am Ende von `_build()` aufrufen,
  damit der Anfangsverkehr schon während des Countdowns sichtbar ist (sonst erscheint er beim „LOS!“);
  (2) `traffic.set_dimensions(SpriteDB.sets)` nach `setup`, damit die Kollisionsmaße zu den Sprites passen;
  (3) optional `ctx.visibility_m` (Sichtweite des Renderers) übergeben; (4) der Autopilot muss bei
  `fuel.state == REFUELING` Gas 0 geben – jeder neue Gasstoß bricht das Tanken ab (Design: „Gas = Weiterfahren“);
  (5) jeden Schritt nach `fuel.update` und vor `police.update`: `police.set_blocked(fuel.holds_car())`
  (gleichwertig: `fuel.state != NORMAL`); (6) bei einem Treffer `space_beside(…, hit)`; (7) Polizeiwagen bei
  `police_car_offset_m()` zeichnen und, solange er neben dem Spieler ist, eine Spur daneben (Seite wählen, solange
  der Versatz < −Kameraabstand − 6 m ist – die Überholanimation beginnt bei −16 m).
- **UI**: `police.caught` kommt jetzt im Stand (Einblendung „Führerschein, bitte!“ passt zur Standzeit),
  `police.pull_over` beim Zugriff; `police.siren_level()` für `AudioManager.set_siren`; `vehicle.rail_hit`/
  `on_grass`/`understeer` für Geräusche. Tanken: solange `fuel.can_abort_refuel()` false ist, statt
  „Gas = Weiterfahren“ z. B. „Tank leer – bitte warten“ zeigen. Abschleppen zählen über `fuel.tow_started` (bzw.
  `tow_finished`), nicht über `ran_dry` (ein leerer Tank kann noch in die Tankspur rollen).
- **Audio/HUD (Untersteuern)**: `understeer` wächst jetzt mit dem Haftungsüberschuss (0,16 bei 4 %, 0,3 bei 7 %, 1 ab
  22 % zu schnell) und ist damit früher hörbar als vorher (Quietschen ab 0,15, HUD-Hinweis ab 0,3 unverändert);
  `vehicle.rail_impact` (m/s) erlaubt einen härteren Aufprallklang, wenn die Abdrift in die Leitplanke geht.
