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
| `tests/unit/gameplay/test_*.gd` | 94 Unit-Tests: Regeln je System + Designzahlen (a)–(h) (`test_design_numbers.gd`) |
| `tests/sim/gameplay_sim.gd` | Simulationen (a)–(i), (b2), (e2), Tabellen; `tests/sim/run_sims.gd` druckt alle |
| `tests/sim/stage_sim.gd` | Etappe mit echtem `StagePlan`/`Track` und Bot-Fahrer, Kollisions-/Ereignisprotokoll |
| `tests/sim/curve_sim.gd` | Nur Kurven: echte Etappe ohne Verkehr/Radar/Tanken, Fahrer mit Bremskurve oder Vollgas – was Kurven kosten |
| `tests/sim/curve_sight.gd`, `sight_check.gd` | Sichtprüfung: reicht Bremsen ab dem Moment, in dem eine Kurve (oder ihr Warnschild) sichtbar wird? |
| `tests/sim/escape_sim.gd`, `check_escapes.gd` | Polizeiflucht im echten Netz: jedes Radarfeld × Auto × Wetter mit kurvenbegrenztem Fahrprofil und echtem `PoliceSystem` (Tabelle (e3); `check_escapes.gd` läuft in `tools/run_tests.sh`) |
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
godot --headless --path . -s res://tests/sim/check_escapes.gd [-- --only=ideal|good]   # ~60 s, Exit-Code
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
  × Wetterhaftung (Regen 0,88, Schnee 0,72; im Tunnel ist die Fahrbahn trocken: 1,0, `Track.grip_at`). Sichere
  Kurvengeschwindigkeit v_sicher = √(a_Haftung · R). `lat_grip` je Agilität 1–5: **5,6 / 6,2 / 6,8 / 7,4 / 8,0 m/s²**
  (vorher 7,6–10,4: damit lagen fast alle Autobahnkurven über vmax). Dazu sind die Autobahnkurven der Kurvigkeit 1
  schärfer geworden (`road.curviness_max_curve[1]` **0,30** statt 0,22, R ≥ 400 statt 545 m): mit 0,22 fuhr der Kompakt
  noch jede Kurvigkeit-1-Kurve mit Vollgas (schärfste sicher bei 238 km/h), auf 31 von 52 Etappen musste er nie vom Gas.
  Weniger Haftung allein hilft dort nicht (5,4–7,0 m/s²: schärfste Kompakt-Kurve 223 km/h = 3 % über vmax, Gegenlenken
  hält) und hätte die Bergstraßen noch langsamer gemacht. Ergebnis (Tabellen (i), (i0)): Kurvigkeit 1 verlangt
  179–204 km/h in der schärfsten Kurve – jedes Auto muss dort vom Gas, der Kompakt in einem Drittel, der Gran Turismo in
  86 % dieser Kurven; Kurvigkeit 2 verlangt 146–166 km/h, Bergstraßen 104–118 km/h.
- **Untersteuern** (kein Übersteuern, kein Dreher): über der Grenze treibt der Überschuss a_ex = v²/R − a_Haftung eine
  Abdrift nach außen an – als **Beschleunigung** (`push_speed` += `push_gain` 2,5 · a_ex · dt), sie baut sich also auf,
  solange der Wagen zu schnell ist. Lenken zur Kurveninnenseite behält max(0,15; 1 − 3 · a_ex/a_Haftung) seiner Wirkung
  (gesättigte Vorderreifen: knapp zu schnell hilft Gegenlenken, deutlich zu schnell nicht), Lenken nach außen wirkt voll.
  Die rutschenden Reifen radieren min(0,5 · a_ex; 3 m/s²) vom Tempo. Unter der Grenze klingt die Drift mit
  `recover_s` 0,25 s ab. Je Schritt exakt integriert (a_ex konstant im Schritt) – bildratenunabhängig.
  `understeer` (0..1, HUD „UNTERSTEUERN“ ab 0,3, Reifenquietschen ab 0,15) = (a_ex/a_Haftung) / `full_excess` 0,5:
  4 % zu schnell ≈ 0,16, 7 % ≈ 0,3, 22 % = 1. **Abhilfe: Gas weg oder bremsen.** Gefühlsziele, alle erfüllt
  (Tabellen (i2), (i2b)): 5 % zu schnell → wer die Spur hält (Gegenlenken proportional zur Abweichung), bleibt durch
  ein ganzes Kurvenstück in ihr (höchstens 0,63 m daneben, auch auf 520 m), ab 8–10 % endet ein langes Kurvenstück an
  der Leitplanke; 15 % → trotz vollem Gegenlenken nach 1,4–1,5 s eine Spur weiter außen; 30 % → aus der Mittelspur in
  1,0–1,1 s auf dem Bankett, 1,2–1,3 s an der Leitplanke. Konfiguration vollständig in `driving.understeer`
  (`scrub_max_mps2` 3) und `driving.shoulder.grip_factor` (0,6).
- **Wer nicht bremst, verliert**: Im ersten Entwurf (ohne geringere Bankett-Haftung und Aufprallverlust) war
  Durchrutschen schneller als Bremsen – Leitplanke, Bankett und Radieren bremsten „gratis“ erst in der Kurve. Jetzt
  kostet Vollgas durch alle Kurven gegenüber gutem Bremsen 12–33 s je Etappe (Tabelle (i4)), mit Verkehr kommt das
  Unfallrisiko beim Abdriften dazu; ein Rutscher in die Leitplanke ist zu spüren (Wackeln, Aufblitzen, renn-modul.md §9).
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
- **Automatik** (`auto_control`): Tempo wird geregelt, Gas ignoriert; ohne `steer_x` lenkt der Spieler weiter
  (Rechts ranfahren, Ausrollen) und **kann stärker bremsen** als vorgegeben (Bremse × 70 km/h/s, wenn das mehr ist als
  die Rate): wer mit leerem Tank (18 km/h/s) auf eine scharfe Kurve zurollt, rutscht sonst unweigerlich in die
  Leitplanke (Limousine, 25 % zu schnell: nach 1,6 s, Tempo halbiert) – mit Bremse bleibt er in der Nachbarspur
  (`test_brake_works_while_rolling_out`). Mit `steer_x` lenkt die Automatik. Der Autopilot bremst beim Ausrollen nur
  für Kurven (Bremsen für die Tankspur würde ihn vor ihr anhalten).
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
  genau für die Standzeit) → `released`. `escape_progress` = min(t/12 s, 1) · clamp((Ø − (Schwelle − 60))/60, 0, 1).
  - **Kurven** (Review: die Polizei fuhr 220 durch jede Kurve, an mehreren Radarfeldern konnte niemand entkommen –
    gegen das Design „Flucht ist möglich ab 220 km/h“): Der Polizeiwagen hält sich an dieselbe Kurvenphysik.
    `update(dt, km, v, road_cap_kmh)` bekommt von der Rennsitzung seine Kurvengrenze an der Position des Spielers
    (`SessionRules.police_curve_cap_kmh`: seine Kurvengeschwindigkeit `curve_speed_mps` – Haftung der
    Agilitätsstufe `police.agility` **1** (5,6 m/s²) × Haftung der Fahrbahn – an jedem Punkt der nächsten 300 m,
    erreichbar mit `police.curve_brake_mps2` 8 m/s²); nach der Kurve steigt sein Tempo mit `police.curve_accel_mps2`
    1,5 m/s² über die gefahrene Strecke wieder an (ein Tempoprofil entlang der Straße, wie ein idealer Polizist).
    `police_kmh` = min(220, Profil) bestimmt den Abstand; die **Fluchtschwelle** `escape_kmh` ist der 12-s-Durchschnitt
    von min(220, Profil) über dieselben Schritte wie der des Spielers: auf der Geraden genau 220 (Design unverändert),
    in Kurven weniger – Flucht heißt jetzt „12 s schneller als die Polizei“ (gleichwertig: der Abstand ist in den
    12 s nicht geschrumpft). Ohne `road_cap_kmh` (INF) ist alles wie vorher. Agilität 1 liegt unter jedem
    Spielerauto (2–5): wie jedes Auto 220 km/h schafft, ist jedes in Kurven schneller als die Polizei (Gran Turismo
    5 %, Kompakt 20 %) – eine strengere Polizei (Agilität 4, Vorschlag des Reviews) ließe den Kombi selbst bei
    idealer Fahrt an 3 (trocken) bzw. 6 (Regen + Nacht) Radarfeldern nicht entkommen, Agilität 2 schon einen Kombi mit
    95 % der Kurvengrenze bei Regen in der Nacht nicht (Tabelle (e3)). Das HUD zeigt die aktuelle Schwelle
    („Flucht ab 187 km/h halten!“).
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
  `auto_control` ohne `steer_x`: die Bremse des Spielers verzögert stärker, wenn sie mehr bringt als die Rate.
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
  Felder `chase_radar, flashes, chases, escapes, stops, blocked, overtake_time`; Kurven: `update(dt, pos_km,
  speed_kmh, road_cap_kmh = INF)`, Felder `police_kmh` (Tempo des Polizeiwagens), `escape_kmh` (Fluchtschwelle),
  `curve_lookahead_m`, `curve_step_m`, `curve_brake_mps2`, Methode `curve_speed_mps(curve, grip)`; `trigger_speed(limit)`,
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

**(e3) Flucht im echten Netz mit Kurven** (`check_escapes.gd`, `escape_sim.gd`: alle 215 Radarfelder beider
Richtungen × 5 Autos, trocken 12 Uhr / Regen 2 Uhr; Fahrprofil ohne Verkehr: Höchsttempo mit Steigung/Wetter/Nacht,
X % der eigenen Kurvengrenze, Bremsen vor Kurven, echte Beschleunigung danach; geblitzt, wo das Profil im Feld zuerst
das Auslösetempo erreicht). Verfolgungen ohne Entkommen je Auto (Kompakt / Kombi / Limousine / Sportwagen / GT):

| Fahrer | Polizei 220 durch jede Kurve (vorher) | Polizei mit Kurvengrenze, Agilität 1 (jetzt) |
|---|---|---|
| ideal: 100 %, Bremsen 70 km/h/s | trocken 5 / 12 / 8 / 4 / 10, Regen + Nacht 11 / 21 / 15 / 7 / 16 | **0** (längste Flucht 17,4 s) |
| gut: 97 %, Bremsen 10 m/s² | – | **0** (19,2 s) |
| 95 %, Bremsen 10 m/s² | – | 0 |
| vorsichtig: 90 %, Bremsen 8 m/s² | – | 1 (Kombi, Regen + Nacht, Barcelona – Montpellier) |

Vorher unentkommbar waren vor allem Erfurt – Kassel km 100 / Kassel km 50 und San Sebastián – Burgos km 50 / Burgos
km 170 (Kurvigkeit 2–3: bester 12-s-Schnitt 137–161 km/h, nach 14–22 s erwischt). Zum Vergleich der Polizei-Agilität
(ideal / 95 % / vorsichtig, Fehlschläge gesamt über alle Autos und beide Wetter): Agilität 1: 0 / 0 / 1; Agilität 2:
0 / 1 / 51; Agilität 4: 9 (Kombi) bei idealer Fahrt. Echte Etappe (`run_stage.gd`, Burgos – San Sebastián, Sportwagen,
Raser-Autopilot bis vmax): 12 Uhr 2 Blitzer, 1 entkommen (Bergstrecke km 170, vorher dort erwischt), 1 erwischt
(km 65 hinter Verkehr mit 120–145 km/h); 3 Uhr (wenig Verkehr) beide entkommen.

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
0,30 / 0,45 / 0,9 = R 400 / 267 / 133 m; Kurvenstärke gleichverteilt 35–100 % davon), in Klammern v0.3.0 (Haftung
7,6–10,4, Kurvigkeit 1 = 0,22), und Anteil der Kurven, für die das Auto bei vmax Gas wegnehmen oder bremsen muss:

| Fahrzeug | Agilität | Haftung m/s² | vmax | Kurvigkeit 1 | Anteil | Kurvigkeit 2 | Anteil | Kurvigkeit 3 | Anteil |
|---|---|---|---|---|---|---|---|---|---|
| Kompakt | 5 | 8,0 (10,4) | 230 | 204 / 248 (271) | 33 % | 166 / 202 (190) | 73 % | 118 / 143 (134) | 100 % |
| Kombi | 3 | 6,8 (9,0) | 235 | 188 / 229 (252) | 56 % | 153 / 187 (176) | 88 % | 108 / 132 (125) | 100 % |
| Limousine | 3 | 6,8 (9,0) | 245 | 188 / 229 (252) | 63 % | 153 / 187 (176) | 94 % | 108 / 132 (125) | 100 % |
| Sportwagen | 4 | 7,4 (9,7) | 255 | 196 / 238 (262) | 63 % | 160 / 195 (183) | 93 % | 113 / 138 (129) | 100 % |
| Gran Turismo | 2 | 6,2 (8,3) | 270 | 179 / 218 (242) | 86 % | 146 / 178 (169) | 100 % | 104 / 126 (120) | 100 % |

Regen × 0,938, Schnee × 0,849 (√Haftung): z. B. schärfste Kurve Kurvigkeit 2 bei Schnee 124 (GT) – 141 km/h (Kompakt).
Begründung der Werte: Mit 5,6–8,0 m/s² bestimmt die Agilität sichtbar das Kurventempo (Spanne 14 % zwischen
Agilität 2 und 5). Die häufigste Straße (Autobahn Kurvigkeit 1, 6 700 von 12 100 km im Netz, dazu 3 900 km ganz
gerade Kurvigkeit 0) verlangt jetzt von jedem Auto Gas weg in den schärferen Kurven, vom Gran Turismo schon in den
mittleren – mit 0,22 fuhr der Kompakt dort alles voll (Review: „Kurven immer mit Top Speed“ galt für ihn weiter).

(i0) Im ganzen Netz (alle 52 Etappen, je eine Richtung, Kurvenstücke außerhalb der City Limits): Anteil der
Kurvenstücke, die mehr als 5 % unter vmax liegen (Gegenlenken hält nicht mehr, Gas weg oder Bremsen nötig), Etappen
ohne ein solches Stück, Kiel – Hamburg; Fahrzeit des idealen Profils (103 % der Kurvengrenze) gegenüber ohne
Kurvengrenze und Etappensiege (51 Etappen ohne Dev-Etappe, ohne Tanken):

| Fahrzeug | Kurvenstücke mit Gas weg (Kurvigkeit 1 = 0,22 / jetzt) | Etappen ohne (0,22 / jetzt) | Kiel – Hamburg | Kurven kosten | Siege |
|---|---|---|---|---|---|
| Kompakt | 17 % / **31 %** | 31 / 4 | 0 → **2** von 6 | +1,1 → +1,4 % | 0 |
| Kombi | 25 % / 52 % | 14 / 2 | 0 → 3 | +2,4 → +3,7 % | 0 |
| Limousine | 33 % / 59 % | 5 / 2 | 2 → 4 | +2,7 → +4,5 % | 0 |
| Sportwagen | 33 % / 59 % | 5 / 2 | 2 → 4 | +2,6 → +4,3 % | 12 → 28 |
| Gran Turismo | 59 % / 82 % | 2 / 0 | 4 → 6 | +6,4 → +10,2 % | 39 → 23 |

Die 2 Etappen ohne Kurve sind ganz gerade (Kurvigkeit 0). Der Gran Turismo bleibt auf geraden Etappen vorn, auf
kurvigen der Sportwagen (Agilität 4, Beschleunigung 5) – kein Auto ist überall überlegen; die Bestenlisten-Starteinträge
(≤ 165 km/h Schnitt) liegen weit unter dem besten idealen Schnitt jeder Etappe (mindestens 207 km/h, Saragossa – Pau).

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

(i2b) Spur halten durch ein echtes Kurvenstück (Ein-/Auslauf je 30 % wie `Track`, Spitze X % zu schnell, Vollgas,
Gegenlenken proportional zur Abweichung von der Mittelspur, `Sim.curve_piece_run`): größte Abweichung nach außen in m,
L = an der Leitplanke (Test `test_counter_steer_holds_slightly_but_not_clearly_too_fast`: 5 % < 1 m bei allen Autos
und Längen, 10 % auf 520 m an der Leitplanke):

| zu schnell | Kompakt 150 / 300 / 520 m | Limousine | Gran Turismo |
|---|---|---|---|
| 3 % | 0,10 / 0,19 / 0,33 | 0,10 / 0,19 / 0,31 | 0,09 / 0,17 / 0,29 |
| 5 % | 0,20 / 0,38 / 0,63 | 0,19 / 0,36 / 0,60 | 0,18 / 0,34 / 0,55 |
| 8 % | 0,42 / 0,99 / L | 0,41 / 0,85 / L | 0,38 / 0,72 / 3,99 |
| 10 % | 0,67 / 3,79 / L | 0,65 / 2,89 / L | 0,60 / 2,15 / L |
| 15 % | 3,68 / L / L | 2,83 / L / L | 2,17 / L / L |

(i3) Erholung (Limousine, 0,6 s zu schnell mit Gegenlenken, dann Vollbremsung): 15 % → nach 0,43 s Bremsen unter der
Grenze, Drift nach weiteren 0,57 s unter 10 %, danach nur noch 0,22 m nach außen, bleibt in der Nachbarspur; 30 % → die
Drift (11,5 m/s) trägt den Wagen noch bis an die Leitplanke.

(i4) Was die Kurven kosten – nur Kurven (`curve_sim.gd`: echte Etappe, ohne Verkehr, Radar, Tanken; Zeit in s).
„vorher Vollgas“ = v0.3.0 (altes Modell und alte Kurvigkeit 1), Vollgas mit Spurhalten (der Spieltest-Befund);
„Autopilot“ = Bremskurve auf 96 % (wie `Autopilot`); „gut“ = bremst spät mit 18 m/s² auf 103 % (leichtes
Untersteuern, Gegenlenken hält); „Vollgas“ = neues Modell ohne Bremsen (Spurhalten = Gegenlenken):

| Etappe | Fahrzeug | vorher Vollgas | Autopilot | gut | Verlust gut ggü. vorher | Vollgas | Vollgas ggü. gut |
|---|---|---|---|---|---|---|---|
| Kassel – Würzburg (Kurvigkeit 1–2) | Kompakt | 280,6 | 294,5 | 288,5 | +7,9 (+2,8 %) | 303,2 | +14,6 |
| | Kombi | 278,9 | 308,8 | 300,0 | +21,1 (+7,6 %) | 333,2 | +33,2 |
| | Limousine | 266,5 | 298,5 | 289,7 | +23,2 (+8,7 %) | 319,1 | +29,3 |
| | Sportwagen | 254,1 | 283,0 | 275,1 | +21,0 (+8,3 %) | 297,7 | +22,6 |
| | Gran Turismo | 247,1 | 297,0 | 284,8 | +37,7 (+15,2 %) | 313,7 | +28,9 |
| San Sebastián – Burgos (0–3) | Kompakt | 304,0 | 332,7 | 327,3 | +23,2 (+7,6 %) | 344,2 | +16,9 |
| | Kombi | 308,1 | 349,6 | 342,1 | +34,0 (+11,0 %) | 361,3 | +19,2 |
| | Limousine | 294,9 | 338,2 | 329,9 | +35,1 (+11,9 %) | 351,5 | +21,6 |
| | Sportwagen | 280,1 | 320,3 | 312,4 | +32,3 (+11,5 %) | 326,4 | +13,9 |
| | Gran Turismo | 277,4 | 331,8 | 323,5 | +46,1 (+16,6 %) | 344,6 | +21,1 |
| Saragossa – Pau (1–3, Landstraße) | Kompakt | 352,7 | 401,6 | 390,4 | +37,7 (+10,7 %) | 404,7 | +14,3 |
| | Kombi | 361,4 | 431,5 | 415,9 | +54,5 (+15,1 %) | 437,7 | +21,9 |
| | Limousine | 347,0 | 418,5 | 402,9 | +55,8 (+16,1 %) | 425,0 | +22,1 |
| | Sportwagen | 329,0 | 395,4 | 381,0 | +52,1 (+15,8 %) | 393,6 | +12,5 |
| | Gran Turismo | 332,2 | 419,8 | 407,0 | +74,8 (+22,5 %) | 418,9 | +11,9 |

Vollgas: 5–61 s auf dem Bankett, 7–23 Leitplankentreffer bzw. Gras je Etappe – Vollgas ist überall 12–33 s langsamer
als gutes Bremsen. Der Autopilot untersteuert nie (`understeer` max 0,00) und verlässt nie die Fahrbahn. Auf kurvigen
Etappen ist der Sportwagen (Agilität 4, Beschleunigung 5) am schnellsten, der Gran Turismo verliert am meisten.

Ganze Etappen mit Verkehr, Radar (befolgt) und Tanken (`run_stage.gd`, Autopilot 235 km/h, 08:00; die drei Etappen
aus (i4) × 5 Autos) gegenüber v0.3.0: im Mittel +12 s je Etappe (Streuung durch Verkehr und Tankentscheidungen
−41 … +94 s); der Autopilot untersteuert nie, keine Leitplanke, 0–1,8 s neben der Fahrbahn (nur Tankspur). Ganze
Rennen (`run_race.gd`, Autopilot, Rennwetter und Tageszeiten je Lauf verschieden), alle fehlerfrei, ohne Blitzer,
Polizeistopp und Abschleppen: Kiel – Nürnberg (Limousine, 235 km/h) v0.3.0 25:20,8 → jetzt 25:03,8 (zweiter Lauf
24:52,7); mit dem Gran Turismo bis vmax (`--autopilot-target=300`, Schnee/Regen auf 4 Etappen) 26:34,4; Königsrennen
(33 Etappen, Limousine) 5:04:10,6 → 5:04:55,2. Die Unterschiede gehen im Rauschen von Wetter, Tageszeit und Verkehr
unter – die Kurven kosten vor allem bei vmax, (i4).
Bestenlisten: Die Starteinträge (`leaderboard.seed_avg_kmh` 125–165 km/h) bleiben schlagbar – der vorsichtige
Autopilot fährt im Königsrennen je nach Tageszeit und Wetter 97–193 km/h Schnitt (Median 150, 10 der 33 Etappen über
dem besten Starteintrag); nur die kurze Tutorial-Etappe mit Pflicht-Tankstopp liegt wie vorher darunter, und der beste
ideale Schnitt liegt auf jeder Etappe bei mindestens 207 km/h ((i0)). Keine Anpassung nötig.

(i5) Sichtprüfung (`curve_sight.gd`, alle 52 Etappen in beiden Richtungen): Reicht es, ab dem Moment zu bremsen, in
dem die Kurve – oder ihr Warnschild – zu sehen ist (Nebel/Nacht-Sichtweite, Kuppen: Sichtlinie aus der Kamera 3,4 m
über der Straße, 9 m hinter dem Auto), mit 1 s Reaktionszeit und Vollbremsung (70 km/h/s), um höchstens 5 % über der
sicheren Geschwindigkeit anzukommen (dort hält Gegenlenken die Linie)? Anfahrt: Vollgas aus der vorigen Kurve bis vmax.

| Fall | ohne Schilder | mit Schildern (erster Entwurf) | mit Schildern (jetzt) |
|---|---|---|---|
| Gran Turismo, Tag (Sicht 900 m) | 27 von 104 Etappenrichtungen zu knapp (bis −46 m) | 0 (+8 m) | **0** (kleinste Reserve +75 m) |
| Gran Turismo, Regen + Nacht (322 m) | – | 1 (−3 m, Kassel – Dortmund, blinde Kurve in den City Limits) | **0** (+76 m) |
| Gran Turismo, Schnee + Nacht (248 m) | – | 0 (+12 m) | **0** (+92 m) |
| Kompakt, Tag | – | 0 | **0** (+261 m) |

Ohne Schilder sind Kurven direkt hinter Kuppen die Falle (die Straße dahinter ist verdeckt, z. B. 153-km/h-Kurve erst
84 m vorher sichtbar). Daher stehen Warnschilder vor scharfen **und vor blinden** Kurven (renn-modul.md §4) – jetzt auch
in den City Limits (dort gibt es kein Radar) und vor Kurven, die ein Abschnittswechsel abschneidet. Mit Kurvigkeit 1 =
0,30 sind mehr Autobahnkurven scharf und damit beschildert; im Tunnel gilt trockene Haftung.

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
  `vehicle.rail_impact` (m/s) erlaubt einen härteren Aufprallklang, wenn die Abdrift in die Leitplanke geht. Die
  Rennsitzung zeigt einen Treffer schon mit Kamerawackeln und kurzem Aufblitzen (renn-modul.md §9); ein Aufprall- bzw.
  Schleifklang nach `rail_impact` fehlt noch (Audio-Modul).
- **Renn-Modul (Polizei in Kurven)**: jeden Schritt einer Verfolgung `police.update(dt, km, v,
  SessionRules.police_curve_cap_kmh(track, police, z, Wetterhaftung))`; ohne diesen Wert fährt die Polizei wie früher
  220 durch jede Kurve. Das HUD liest die aktuelle Fluchtschwelle aus `police.escape_kmh` (HUD-Schlüssel `escape_kmh`).
