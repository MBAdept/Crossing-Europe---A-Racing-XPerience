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
| `tests/unit/gameplay/test_*.gd` | 103 Unit-Tests: Regeln je System + Designzahlen (a)–(h) (`test_design_numbers.gd`, seit v0.5.0 mit den Abweichungen von den Design-Startwerten als festen Zahlen) |
| `tests/sim/difficulty_sim.gd` | Schwierigkeit (Tabelle (j)): echte Etappen mit Verkehr, Fahrer „naiv“ (weicht nur aus), „spät“ (bremst wie auf trockener Straße) und Autopilot – Kollisionen, Annäherung, blockierte Spuren, Spurwechsel |
| `tests/sim/gameplay_sim.gd` | Simulationen (a)–(i), (b2), (e2), Tabellen; `tests/sim/run_sims.gd` druckt alle |
| `tests/sim/stage_sim.gd` | Etappe mit echtem `StagePlan`/`Track` und Bot-Fahrer, Kollisions-/Ereignisprotokoll |
| `tests/sim/curve_sim.gd` | Nur Kurven: echte Etappe ohne Verkehr/Radar/Tanken, Fahrer mit Bremskurve oder Vollgas – was Kurven kosten |
| `tests/sim/curve_sight.gd`, `sight_check.gd` | Sichtprüfung: reicht Bremsen ab dem Moment, in dem eine Kurve (oder ihr Warnschild) sichtbar wird ((i5))? Mit `--traffic`: ab dem Moment, in dem das langsamste Fahrzeug des Wetters aus dem Nebel oder hinter einer Kuppe auftaucht ((i6))? |
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
      [--weather=snow] [--night] [--reaction=1.0] [--top-speed] [--no-signs] [--tolerance=0.05] \
      [--traffic [--no-crests] [--hour=19.5] [--queue=0.9] [--target-h=0.75]]   # (i6) Verkehr statt Kurven
godot --headless --path . -s res://tests/sim/check_escapes.gd [-- --only=ideal|good]   # ~60 s, Exit-Code
godot --headless --path . -s res://tests/sim/difficulty_sim.gd -- [--stages=kassel_wuerzburg,saragossa_pau,hamburg_hannover] \
      [--weathers=normal,rain,snow] [--hours=7.5,0.5] [--drivers=naive,late,autopilot,dryhabit] [--km=40] [--json=<datei>]
```

## Entscheidungen (offene Punkte des Design-Dokuments)

| Offener Punkt | Entscheidung (Konfiguration) |
|---|---|
| Wie stark senken Regen, Schnee und Nacht die Höchstgeschwindigkeit? | Regen −2,5 % (`driving.weather_vmax_factor.rain` 0,975), Schnee −12 % (0,88), Nacht −1 % (`driving.night_vmax_factor` 0,99, weich über die Dämmerung). Regen + Nacht = −3,5 %: das langsamste Auto (230) schafft 222 km/h → Flucht möglich; Schnee verhindert sie bei Kompakt/Kombi/Limousine. Haftung seit v0.5.0 (Spieltest: „Schnee macht die Steuerung nur leicht schwammiger, ohne ernsthafte Probleme“): Reifenhaftung Regen 0,75, Schnee 0,45 (vorher 0,88/0,72, nur für die Kurvengrenze), wirkt auf Kurvengrenze, Bremsen, Traktion und Lenken (Abschnitt „Wetter“). **Steigung**: bis `driving.grade_free_percent` (4 %) kein Verlust, darüber 1,2 % je Prozentpunkt (`grade_vmax_loss_per_percent`). „Leicht verschlechterte Bedingungen“ (Design: jedes Auto schafft dann noch 220 km/h) = Regen und/oder Nacht auf normalem Hügelland bis Hügelstufe 2 (≤ 4,5 %): Kompakt bei Regen + Nacht an 4,5 % noch 220,7 km/h, Flucht gelingt (Tabellen (e), (f)). Deutlich schlechter = Schnee oder steile Bergstrecken (Hügelstufe 3, 7 %: −3,6 %, Kompakt bei Regen + Nacht 214 km/h). |
| Länge der Zeitstrafe bei leerem Tank | `fuel.tow_penalty_s` = **90 s** Strafe + Ausrollen (18 km/h/s) + 4 s Einblendung `TOWING`, danach halber Tank (`tow_refill_fraction` 0,5). Effektiv ≈ 110 s, etwa das 2,5-Fache eines vollen Tankstopps (25 s + Bremsen/Anfahren). Wer mit leerem Tank in eine Tankspur rollt, tankt dort normal (kein Abschleppen) – ein leeres Auto in der Tankspur wird nie abgeschleppt, und Gas bricht das Tanken erst ab, wenn mindestens `fuel.abort_min_fuel_l` (1 L) im Tank sind. |
| Verhalten am Straßenrand | **Bankett** (2,5 m, `road.shoulder_width_m`): ragt die Karosserie > 0,5 m über den Fahrbahnrand, bremst der Wagen auf 90 km/h (35 km/h/s), `off_road = 1`; loser Belag: dort nur 60 % Kurvenhaftung (`driving.shoulder.grip_factor` 0,51, mit Exponent 0,75 = 0,60), ein untersteuernder Wagen rutscht also weiter. **Harte Grenze** am Bankettende: mit Leitplanke (Autobahn) Kontakt → Tempo × 0,9 je Treffer (höchstens alle 0,6 s), Abprallen mit 1,5 m/s nach innen, Schleifen 20 km/h/s – nur solange Lenken oder Abdrift den Wagen gegen die Leitplanke drücken: ein Wagen, der sie nur berührt oder dort steht (nach einem Unfall, beim Rechtsranfahren), fährt mit Gas frei weg (Review v0.5.0: im Schnee liegt die Traktion mit 11,9 km/h/s unter dem Schleifen – der Wagen blieb sonst für immer stehen, `test_guardrail_never_pins_a_standing_car`); trifft die Untersteuer-Abdrift die Leitplanke, kostet jeder m/s über 1 m/s weitere 5 % (`driving.guardrail.impact_*`, bis Tempo × 0,5 – ungebremst seitlich hinein); ohne Leitplanke (Landstraße, Stadt) **Gras** → stark bremsen auf 40 km/h (60 km/h/s); beides `off_road = 2`, die Abdrift endet dort. |
| Wetter im Rennen | `weather.race_mode`: `region` (Standard, gewichtet nach Klima des Etappenlandes), `random` (gleichverteilt), `fixed` (Feld `weather` der Etappe, sonst Region). `EnvironmentModel.race_weather(plan, race_seed, leg_index)` ist deterministisch. Seit dem Review v0.5.0 fährt die Tutorial-Etappe (Kiel – Hamburg) immer bei `weather.tutorial_weather` = trocken (`RaceState.leg_weather`): vorher bekam sie das Rennwetter (Norden: 32 % Regen, 8 % Schnee) – ein Erstspieler hatte dann die halbe Bremsung und einen nachrutschenden Wagen, ohne jeden Hinweis (Autopilot Kompakt: trocken 287 s, Schnee 434 s). Alle anderen Etappen behalten das Rennwetter; jede Regen- oder Schnee-Etappe zeigt beim Countdown, was das Wetter bewirkt („Schnee: Bremsweg ×2, der Wagen rutscht nach dem Spurwechsel weiter – früh gegenlenken“, `SessionRules.weather_hint`, Faktor aus `driving.grip_effects`). |
| Abweichungen von Startwerten des Design-Dokuments (v0.5.0, Spieltest „zu leicht“) | (1) Verkehr nachts nicht mehr schneller (Design: +15 %, Spielraum 15–20 %; `traffic.night.speed_factor` 1,0), (2) Lkw auf der Autobahn 80–90 km/h, Busse 95–100 km/h (Design: alle Fahrzeuge 110–150; Pkw bleiben im Design-Bereich), (3) Regen und Schnee machen den Verkehr langsamer (Pkw × 0,85 / × 0,65). Das Design-Dokument nennt die Werte ausdrücklich Startwerte; es steht noch auf ihnen, bis der Nutzer die Änderungen bestätigt. `test_design_numbers.gd` prüft die neuen Zahlen ausdrücklich (nicht die Konfiguration gegen sich selbst). |

Weitere Festlegungen:

- **Beschleunigung**: dv/dt = a0·(1 − v/vmax)^(1−q), a0 und q je Fahrzeug so gelöst, dass 0–100 und 0–200 km/h exakt
  den Zielen der Beschleunigungsstufe entsprechen; analytisch integriert (bildratenunabhängig), vmax wird in endlicher Zeit
  erreicht (q > 0). Die Kurve gilt relativ zur aktuellen Höchstgeschwindigkeit (Wetter/Nacht/Steigung). Über dem Maximum
  (z. B. bergauf) sinkt das Tempo mit 12 km/h/s darauf ab. Steigungen bis 4 % senken das Maximum nicht (siehe oben).
- **Lenken**: seitlich `steer_mps` der Agilitätsstufe, linear ab 0 bis 60 km/h hochgefahren, Ansprechzeit 0,12 s
  (trocken; bei Regen und Schnee träger und mit Nachrutschen, Abschnitt „Wetter“).
  Der Wagen folgt der Straße; unterhalb der sicheren Kurvengeschwindigkeit gibt es keinerlei Abdrift.
- **Kurvengrenze** (seit v0.3.0-Playtest: „Kurven gehen immer mit Top Speed“): die Kurve verlangt die Querbeschleunigung
  a = v²/R (R = `road.curve_radius_at_1_m` 120 m / |Kurve|), die Reifen geben a_Haftung = `lat_grip` der Agilitätsstufe
  × Kurvenhaftung (seit v0.5.0 Wetterhaftung^0,75: Regen 0,81, Schnee 0,55 – vorher 0,88/0,72; im Tunnel ist die
  Fahrbahn trocken: 1,0, `Track.grip_at`). Sichere
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
  (`scrub_max_mps2` 3) und `driving.shoulder.grip_factor` (0,51 = 0,6 Kurvenhaftung).
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
- **Verkehr** (seit v0.5.0 ein echtes Hindernis – Regeln und Messungen im Abschnitt „Verkehr als Hindernis“):
  - Wunschtempo je Fahrzeug = fester Anteil (Temperament) im Bereich seiner Klasse und des Straßentyps, begrenzt durch
    das Tempolimit, mal Wetterfaktor (`TrafficSystem.cruise_speed_for`); Straßentypwechsel (Autobahn → Landstraße →
    City) übernimmt jedes Auto sofort als neues Wunschtempo. Lkw und Busse fahren realistisch langsamer (Autobahn
    80–90 bzw. 95–100 km/h) – bis v0.4 am langsamen Ende des Pkw-Bereichs (110–120), was das Überholen zu leicht machte.
    Nachts kein Tempobonus mehr (vorher +15 %).
  - Folgefahren: Intelligent Driver Model (a = 1,6 m/s², Lkw 0,7; komfortabel 2,5, max. 8 m/s²; Mindestabstand 14 m +
    1,2 s, bei Regen/Schnee länger). Bremslicht ab 0,6 m/s² Verzögerung und im Stand.
  - Spurwechsel: MOBIL (Vorteil > 0,2 m/s², Lkw nach links > 0,6; Sicherheit: neuer Hintermann muss nicht stärker als
    3 m/s² bremsen – außer dem Spieler, s. „Einscheren“; Höflichkeit 0,3; Rechtsfahrgebot +0,3 m/s² auf
    Autobahn/Landstraße). Jeder Spurwechsel wird mit dem Blinker angekündigt (1–1,5 s vorher). Lkw nie auf die linke
    Spur einer dreispurigen Straße. Endet eine Spur (Vorausschau 60 m + 6 s), wird zwingend eingefädelt: seit dem
    Review v0.5.0 blinkt das Auto sofort und wartet blinkend auf die Lücke (`Car.signal_merge`), und der Verkehr der
    Zielspur lässt es im **Reißverschluss** herein – wer bis zu `traffic.blink.zipper_m` (60 m) hinter ihm fährt (mindestens
    6 m Lücke), behandelt es als Vordermann. Ohne Lücke hält es vor dem Spurende an, dann aber mit Blinker. Vorher hielten
    die Autos der endenden Spur unangekündigt an ihrem Ende, und die Mittelspur der Autobahn stand dahinter
    (`qa_traffic_rules`, 150 s ab 10–12 km davor, Zeit mit stehenden Autos in Sicht: Hamburg – Bremen 17:30 13,9 → 3,0 s,
    Bremen – Amsterdam 11:54 10,6 → 0 s, Hannover – Kassel 08:00 22,4 s mit bis zu 3 Autos → 10,6 s mit einem blinkenden;
    `test_zipper_at_a_lane_drop`). Dasselbe gilt für das Verlassen der Tankspur.
  - **Keine rollenden Straßensperren** (vorher fuhren zwei Autos mit 74/75 km/h minutenlang nebeneinander und
    sperrten eine Landstraße). Ausnahme seit v0.5.0: ein Lkw, der einen langsameren überholt (**Elefantenrennen**),
    behält sein Tempo bis `traffic.elephant.max_s`. Ein Auto auf einer linken Spur prüft die
    Verkehrsautos auf der Spur rechts (70 m dahinter bis 40 m davor, `side_window_*`), die es nicht ohnehin um
    mindestens `yield_speed_margin_kmh` (6 km/h) überholt:
    - **zügig überholen**, wenn sie höchstens 6 km/h schneller sind, als es fahren will, und es innerhalb seines
      Tempobereichs klar schneller sein kann: Wunschtempo + `pass_boost_kmh` (10 km/h), höchstens oberes Ende des
      Design-Bereichs (× Nachtfaktor); danach ordnet es sich rechts ein. 74 neben 75 km/h → überholt mit 85 km/h;
    - sonst (ein klar schnelleres Auto kommt rechts auf, oder es kann nicht klar schneller sein, z. B. Lkw auf
      der Landstraße) **zurückfallen**: auf deren Tempo − `yield_slowdown_kmh` (15 km/h, nie über dem eigenen
      Wunschtempo), dahinter rechts einordnen (Rechtsfahrgebot + `yield_keep_right_bonus_mps2` 1,0 m/s², dabei
      kein Ausweichen nach links). Kein Wettrennen mit einem schnelleren Auto, das rechts vorbei will. Wer
      zurückfällt, tut das, bis der andere `side_yield_hold_m` (40 m) jenseits des Fensters ist (seit v0.5.0: ohne
      dieses Haltefenster pendelte ein Auto an der Fenstergrenze – genau neben einem Spieler, der dem Lkw folgt; im
      Schnee sperrte das auf Saragossa – Pau 52 km lang die Überholspur, Test
      `test_yielding_car_does_not_hover_beside_the_player`: blockiert 22 statt 100 % der Zeit).
    Die Tempo-Abstände (6, 10, 15 km/h) gelten trocken; bei Regen und Schnee schrumpfen sie mit dem Wetterfaktor
    der Pkw (Schnee × 0,65: 3,9 / 6,5 / 9,75 km/h) – alle Tempi sind dort ein Drittel niedriger, sonst könnte im
    Schnee fast kein Auto mehr einen Lkw zügig überholen.
    Der Spieler zählt nie (er regelt sein Tempo selbst – ein Auto, das sich nach ihm richtet, bliebe neben ihm
    und sperrte ihm die Überholspur). Neue Autos erscheinen nicht dort, wo sie sofort zurückfallen müssten.
    Ergebnis: längstes Nebeneinander gleich schneller Autos in den Landstraßen-Simulationen ≤ 0,6 s (ohne die
    Regeln 17–41 s), Testfall 74/75 km/h ≈ 2 s; Spuranteile und Spurwechsel wie ohne die Regeln.
  - Spieler: zählt als Hindernis in jeder Spur, in die seine Karosserie ragt. Autos bremsen hinter ihm (IDM) und
    überholen links (oder rechts, wenn er sie bedrängt). In allen Simulationen fuhr kein Auto in den Spieler. Vor ihm
    machen sie seit v0.5.0 keinen Platz mehr: sie scheren vor einem schnell herankommenden Spieler ein, nie aber
    näher, als er noch bremsen kann (Abschnitt „Verkehr als Hindernis“).
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

## Schwierigkeit (v0.5.0)

Spieltest v0.4.0: „Der Schwierigkeitsgrad ist zu niedrig, … man kann zu leicht an anderen Autos vorbeifahren … selbst
bei Top-Speed sind die Gegner ‚schnell‘ genug, dass ich easy in aller Ruhe überhole, und Schnee macht die Steuerung
nur leicht schwammiger, ohne ernsthafte Probleme zu verursachen.“ Ursachen (gemessen, Tabelle (j)): Pkw fuhren
110–150, Lkw 110–120 km/h und nachts 15 % schneller – kleine Annäherungsgeschwindigkeit; der Verkehr machte dem Spieler
Platz (kein Auto zog vor einem schnell herankommenden Spieler heraus: die MOBIL-Sicherheitsregel verlangte bei
230 gegen 130 km/h rund 390 m Lücke); Schnee senkte nur die Kurvengrenze; im Schnee fuhr der Verkehr unverändert schnell,
die Annäherung war dort sogar am kleinsten. Ziel: Verkehr als echtes Hindernis, Regen und Schnee mit ernsten Folgen
für die Fahrzeugbeherrschung – fair (alles vorher sichtbar, nichts unvermeidbar) und mit unveränderten Designregeln
(Flucht bei leicht verschlechterten Bedingungen, kein Übersteuern, kein Dreher).

Ergebnis (Tabelle (j), gleiche Etappen vorher/nachher): Annäherung an den Verkehr im Median trocken 109 → 112 km/h
(nachts 83 → 123, Schnee 78 → 117); im Berufsverkehr sind alle Spuren innerhalb des Bremswegs trocken doppelt, bei Regen
dreimal und bei Schnee neunmal so oft zu; ein Fahrer, der nie für Autos bremst, kollidiert 1,7-mal so oft
(1,86 → 3,13 je 100 km), einer, der im Schnee wie gewohnt bremst, jetzt überhaupt (0 → 1,13 je 100 km Schnee); der
vorsichtige Autopilot bleibt kollisionsfrei, ist trocken 5–8 %, bei Regen 7–14 % und bei Schnee 8–25 % langsamer (Stand
nach dem Review).
Polizeiflucht (`check_escapes.gd`) und Sichtprüfung der Kurven (i5) bleiben grün.

**Nach dem Review** (fair heißt: alles vorher sichtbar, nichts unvermeidbar – geprüft mit (i6) und einem simulierten
menschlichen Fahrer): Bei Schnee in der Nacht reichte die Sicht (248 m) nicht mehr für den halbierten Bremsweg – eine
langsame Kolonne aus dem Nebel ließ sich nur umfahren. Jetzt: Sicht bei Schnee nachts 338 m (Abschnitt „Wetter“), City
Limits 4 km (333 m) vorher angekündigt (Vorschild und „City Limits Würzburg in 4 km – Tempo 50“), der Verkehr bremst bei
Regen und Schnee sanfter (Schnee höchstens 4 statt 8 m/s²), das Einscheren rechnet auch im Tunnel mit der Bremsung des
Wetters, Blinker sind auf 150–250 m deutlich zu sehen, die Tutorial-Etappe ist immer trocken, und jede Regen- oder
Schnee-Etappe sagt beim Countdown, was das Wetter bewirkt. Die Schwierigkeit selbst bleibt (Tabelle (j)).

### Verkehr als Hindernis

| Regel | Umsetzung (`traffic.*`, `TrafficSystem`) |
|---|---|
| Realistische Tempi je Klasse | Pkw im Design-Bereich (`speeds_kmh`: Autobahn 110–150, Landstraße 70–100, City 40–60), Lkw `truck_speeds_kmh` (Autobahn **80–90**, Landstraße 65–80, City 35–50), Busse `bus_speeds_kmh` (Autobahn **95–100**), `bus_share` 20 % der schweren Fahrzeuge. Temperament je Fahrzeug (0..1) wählt das Tempo im Bereich. |
| Tempolimits | Pkw höchstens Limit × `limit_tolerance` (0,92 vorsichtig … 1,12 schnell): niederländische Autobahn (100) 92–112, französische (130) 110–146, City (50) 40–56; Lkw/Busse höchstens das Limit. Das Limit kommt aus der Strecke (`Track.speed_limit_at`, 0 = frei). |
| Rechts langsam, links schnell | neue Pkw wählen die Spur nach Tempo: (1 − Temperament) · (Spuren − 1) ± `lane_speed_spread`/2 – rechts die langsamen (und alle Lkw), links die schnellen; das Rechtsfahrgebot hält die Ordnung. |
| Nacht | `night.speed_factor` **1,0** (Design-Startwert +15 %: schnellerer Verkehr machte das Überholen nachts noch leichter); ruhiger bleibt die Nacht durch die Tageskurve (12–27 % der Spitzendichte). |
| Wetter | `traffic.weather.<w>`: Regen Pkw × 0,85, Lkw × 0,88, Abstände × 1,3 (Zeitlücke) / × 1,2 (Mindestabstand), Spurwechsel × 0,85; Schnee Pkw × **0,65** (Autobahn 72–98 km/h), Lkw × 0,68 (54–61 km/h), Zeitlücke × 1,8, Mindestabstand × 1,5, Spurwechsel × 0,65 (vorsichtig, zwei Spuren länger belegt). Bremsen (Review): `decel_factor` Regen 0,78, Schnee 0,5 auf komfortables (2,5 m/s²) und stärkstes Bremsen (8 m/s²) – wie die Vollbremsung des Spielers etwa Haftung^0,87; im Schnee bremst der Verkehr höchstens mit 4 m/s² (vorher 8 – fast die ganze Schneebremsung des Spielers, 9,7) und fängt dafür früher an. Hinter dem Spieler gilt weiter die trockene Grenze: er darf voll bremsen oder einscheren, ohne dass ihm einer auffährt (`test_traffic_brakes_softer_in_snow`). Die Tempo-Abstände der Regel gegen rollende Sperren schrumpfen mit (Abschnitt „Verkehr“). Die Rennsitzung gibt `ctx.weather`. |
| Blinker | Jeder Spurwechsel wird angekündigt: der Blinker geht `blink.lead_s` (1,0–1,5 s je Auto, Lkw/Busse × 1,3, Pflichtwechsel 1,0 s) **bevor** das Auto zieht; ohne sichere Lücke wartet es blinkend (höchstens `max_wait_s` 3 s, dann gibt es auf), es bricht ab, wenn der Wechsel sich nicht mehr lohnt, und der Blinker bleibt an, bis es in der neuen Spur ist. Nur das Ausweichen vor einem langsameren Spieler (Notfall) geht sofort. Gezeichnet als bernsteinfarbene Leuchte am Heck (renn-modul.md §8) – mit Mindestgröße auch in 150–250 m deutlich, nachts so lange sichtbar wie die Rücklichter (Review). |
| Kein Platzmachen mehr (**Einscheren**) | Kommt der Spieler in der Zielspur schneller heran, beurteilt der Fahrer ihn wie im Spiegel: er sieht den Abstand und höchstens `cut_in.perceived_max_kmh` (72 km/h) Annäherung und will davon `judge_s` (5 s vorsichtig … 2,5 s mutig = schnell) plus `judge_add_m` (20 m) – vor einem Spieler mit 230 km/h zieht er also heraus, wo ihn die alte Regel noch 390 m hätte warten lassen. |
| Fairness-Untergrenze | Nie näher als `cut_in_floor_m`: Relativtempo v_rel · (Blinkzeit + `intrude_s` 0,5 s + `margin_s` 0,3 s) + v_rel² / (2 · `brake_fraction` 0,7 · Vollbremsung des Spielers **im aktuellen Wetter**, `ctx.brake_mps2` – mit der Haftung des Wetters, auch im Tunnel: sonst zöge ein Auto hinter der Tunnelausfahrt mit der trockenen Untergrenze heraus, die der Spieler draußen im Schnee nicht mehr schafft, Review) + `margin_m` 8 m. Wer auf den Blinker hin – oder spätestens, wenn das Auto herüberzieht – mit 70 % seiner Bremsleistung bremst, bleibt dahinter. Beim Losziehen wird erneut geprüft (ohne Blinkzeit): hat der Spieler beschleunigt oder die Spur gewechselt, wartet das Auto. Bei 230 gegen 82 km/h (Lkw-Kolonne) trocken ≥ 154 m beim Blinken, im Schnee (205 gegen 55 km/h) ≥ 220 m. Test `test_cut_in_in_front_of_a_fast_player_is_fair`. |
| **Elefantenrennen** | Auf Straßen mit 3+ Spuren (`elephant.min_lanes`, nicht in den City Limits) überholt ein Lkw/Bus ein mindestens 3 km/h langsameres schweres Fahrzeug innerhalb 120 m (`min_diff_kmh`, `look_m` – so weit hinten pendelt sich ein Lkw mit 3 km/h Unterschied im IDM ein; Vorteil `bonus_mps2`) in seinem eigenen Tempo – rechte und mittlere Spur sind dann mit Lkw-Tempo zu, links bleibt die Überholspur. Die Regel gegen rollende Sperren gilt für ihn erst nach `max_s` (45 s): dann gibt er auf, fällt zurück, blinkt rechts und wird hereingelassen wie am Spurende (Reißverschluss), und versucht es frühestens nach `retry_s` (60 s) wieder. Review v0.5.0: nach dem Aufgeben zählt jedes schwere Fahrzeug rechts neben ihm, auch wenn es um mehr als die (im Schnee auf 3,9 km/h geschrumpfte) Tempo-Marge langsamer ist – vorher ging ein Lkw mit 5 km/h Unterschied im Schnee als „gewöhnliches Überholen“ weiter, längstes Rennen 121 s; jetzt längstens 61 s bis zurück rechts (Hamburg – Bremen 08:00, Schnee, 300 s; Test `test_elephant_race_gives_up_in_snow`). Gemessen: 80 gegen 90 km/h, 28 m dahinter: schert nach 1,6 s aus, 17,5 s Seite an Seite, nach 48,6 s vorbei und wieder rechts; 84 gegen 88 km/h: gibt nach 45 s auf. Auf zweispurigen Straßen überholen Lkw nicht (Test `test_elephant_race_on_three_lanes_only`). |
| Kolonnen und Gruppen (`cluster`) | Neuer Verkehr vorn kommt mit `chance` (Autobahn/Landstraße 35 %, City 40 %) als Gruppe aus 1 + `followers` (1–3): eine Kolonne hinter einem langsamen Fahrzeug (Lkw/Bus mit 2,5-fachem Lkw-Anteil, sonst ein langsamer Pkw; die Hintermänner im `gap_factor`-fachen IDM-Abstand, `patience_s` 4–20 s ohne Überholversuch) oder auf 3+ Spuren (`elephant_share` 30 %) ein Elefantenrennen samt Autos dahinter. Eine Gruppe wartet, bis im Fenster so viele Fahrzeuge fehlen: erst eine leere Strecke, dann die Gruppe – die mittlere Dichte bleibt gleich, die Abstände streuen stärker (Variationskoeffizient der Abstände entlang der Straße, alle Spuren, 08:00, Spieler 200 km/h: ohne Gruppen 0,77, mit 0,90; Test `test_traffic_comes_in_clusters`). |
| Dichte | Grunddichte Autobahn **16** (vorher 14), Landstraße **10** (9), City 8 (× 2,5 in den City Limits); Tageskurve unverändert (Spitzen 7–9 und 16–19 Uhr). |

### Wetter

Eine Reifenhaftung g je Fahrbahn (`driving.weather_grip_factor`: trocken 1,0, Regen **0,75**, Schnee **0,45**; im Tunnel
trocken), jede Steuerung mit eigener Empfindlichkeit (`driving.grip_effects`, `VehicleModel`):

| Wirkung | Formel | trocken | Regen | Schnee |
|---|---|---|---|---|
| Kurvengrenze (`curve_grip`) | lat_grip · g^0,75 (Spieler und Polizei) | 1,00 | 0,81 (Kurventempo × 0,90) | 0,55 (× 0,74) |
| Vollbremsung (`brake_decel_mps2`) | 70 km/h/s · g^0,87 | 19,4 m/s² | 15,2 m/s² | 9,7 m/s² (≈ halb) |
| Bremsweg 200 → 100 km/h | gemessen | 59 m / 1,4 s | 77 m / 1,9 s | 119 m / 2,9 s |
| Traktion (`traction_mps2`) | 9 m/s² · g^1,25 | über jedem Auto | 6,3 m/s² (nur ganz unten spürbar) | 3,3 m/s²: 0–100 km/h für jedes Auto ≈ 8,4 s (trocken 3,8–7,0 s) |
| Ansprechzeit der Lenkung (`steer_response_s`) | 0,12 s / g^1,75 | 0,12 s | 0,20 s | 0,49 s |
| Querbewegung bei vollem Einschlag (`steer_speed_mps`) | steer_mps · g^0,3 | 7,5–10,5 m/s | × 0,92 | × 0,79 |
| Nachrutschen: Spurwechsel bei 200 km/h, am Ziel losgelassen | gemessen (Limousine) | 1,2 m | 1,6 m | **2,9 m** (in die Nachbarspur) |

Die Quergeschwindigkeit folgt der Lenkung erster Ordnung mit der Ansprechzeit; nach dem Loslassen rutscht der Wagen um
etwa Quergeschwindigkeit × Ansprechzeit weiter, Gegenlenken halbiert das (Test `test_steering_slides_on_snow`). Nie mehr
Querbewegung als voller Einschlag, kein Übersteuern, kein Dreher: der sichtbare Gierwinkel folgt weiter der
Quergeschwindigkeit. Die Kurvengrenze sinkt bewusst schwächer als die Haftung (Exponent 0,75; mit g selbst wären
Bergstraßen bei Schnee 73 statt 80 km/h, Autobahnkurven 126 statt 139 km/h) – die Arcade-Kurvengrenze ist schon im
Trockenen niedrig. Das Bankett (`driving.shoulder.grip_factor` 0,51 = 0,6 Kurvenhaftung wie bisher) gilt nur für die
Kurvengrenze. Höchsttempo (Regen 0,975, Schnee 0,88) und Sicht am Tag (Regen 0,65, Schnee 0,5) bleiben. **Sicht bei
Schnee in der Nacht** (Review): mit der halben Bremsung war der Anhalteweg aus Höchsttempo länger als die Sicht – eine
langsame Kolonne (City Limits im Schnee: 21–26 km/h), die aus dem Nebel auftauchte, ließ sich nur noch umfahren, und waren
alle Spuren zu, war der Unfall unvermeidbar (Gran Turismo bis 47 m zu kurz, (i6)). Schnee hellt die Nacht auf: der
Nachtfaktor der Sicht gilt je Wetter (`weather.night_visibility_factor`: trocken und Regen 0,55, Schnee **0,75**), Schnee
nachts 338 statt 248 m (Dämmerung 19:30: 377 m; Regen nachts weiter 322 m). Damit kommt jedes Auto aus Höchsttempo hinter
dem langsamsten Verkehr jedes Wetters zum Stehen ((i6): kleinste Reserve 28 m), die Kurven-Sichtprüfung bleibt grün ((i5):
28 m, eine Kurve hinter einer Kuppe – dort entscheidet nicht der Nebel).

**Autopilot** (renn-modul.md §10): plant mit 75 % der Bremsung des Wetters, folgt langsamem Verkehr auf einer
Bremskurve, sieht Blinker als belegte Spur, braucht im Schnee größere Lücken und lenkt mit einem auf die Ansprechzeit
abgestimmten PD-Regler – keine Kollision, kein Ausflug neben die Fahrbahn bei keinem Wetter (Tabelle (j),
`tests/unit/race/test_autopilot_weather.gd`).

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
- v0.5.0 `TrafficSystem`: `update` liest `ctx.weather` (Tempo, Abstände, Spurwechseltempo des Verkehrs) und
  `ctx.brake_mps2` (Vollbremsung des Spielers – Untergrenze fürs Einscheren); `cruise_speed_for(road, cls, frac,
  limit = 0)` (Wunschtempo einer Klasse 0 Pkw / 1 Lkw / 2 Bus), statisch `vehicle_class(car)`, `cut_in_floor_m(rel_mps,
  lead_s = 0)`; Felder `weather`, `player_brake_mps2`, `cut_ins` (Einscheren vor dem schnelleren Spieler, Statistik),
  `last_cut_in` {id, gap_m, rel_kmh, floor_m, car_kmh, player_kmh}. `Car`: `bus`, Blinker `signal_dir` (−1/0/+1),
  `signal_lane`, `signal_t` (Zeit bis zum Losziehen), `signal_age` (seit dem Einschalten – Blinktakt), `signal_wait`,
  `signal_mandatory`, `signal_merge` (Review: muss seine Spur verlassen – Spurende, Tankspur, aufgegebenes
  Elefantenrennen; blinkt sofort, Reißverschluss); Elefantenrennen `elephant_t` (−1 = nein), `elephant_cool`. Die Strecke darf `speed_limit_at(z)`
  liefern (0 = frei; `FakeTrack` mit Feld `limit` je Abschnitt).
- Review v0.5.0: `TrafficSystem.slowest_speed_kmh(road, limit, heavy = -1)` (langsamstes Wunschtempo: Pkw, Lkw/Busse oder
  alle), `set_weather(w)`, `traffic.weather.<w>.decel_factor` (Bremsen des Verkehrs, hinter dem Spieler trocken);
  `EnvironmentModel.night_visibility_factor(w)` (`weather.night_visibility_factor` als Zahl oder je Wetter),
  `race_weather` gibt der Tutorial-Etappe `weather.tutorial_weather`.
- v0.5.0 `VehicleModel`: `curve_grip(g)`, `brake_decel_mps2(g)`, `traction_mps2(g)`, `steer_response_s(g)`,
  `steer_speed_mps(g)`, `traction_crossover(vtop, trac_kmh_s)`; `accelerate(v, vtop, t, trac_kmh_s = INF)` mit
  Traktionsgrenze (exakt integriert). `road.grip` wirkt auf Kurvengrenze, Bremsen (auch die Spielerbremse beim
  Ausrollen), Traktion und Lenken. `PoliceSystem.curve_speed_mps(curve, grip)` nutzt dieselbe Kurvenhaftung.

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

v0.5.0 (Regen: Reifenhaftung 0,75, Kurvenhaftung 0,81 für Spieler **und** Polizei; der ideale Fahrer bremst höchstens
mit der Vollbremsung des Wetters, bei Regen 15,2 m/s²): `check_escapes.gd` weiter grün – ideal **0** (längste Flucht
15,5 s), gut **0** (16,3 s) von je 2 150 Verfolgungen. Die Polizei verliert in Regenkurven so viel wie der Spieler, die
Flucht bei leicht verschlechterten Bedingungen bleibt möglich; Schnee darf sie verhindern (Design).

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

**(g) Verkehr** (v0.5.0: Autobahn-Grunddichte 16 Fz/km, Landstraße 10, Stadt 8; Tageskurve `traffic.hourly_density`)

| Größe | Wert |
|---|---|
| Dichte 08:00 / 03:00 | 16,0 / 1,92 Fz/km (03:00 = 12 % von 08:00); 12:00 11,2; 17:30 15,8; 23:30 3,9 (v0.4: 14,0 / 1,68) |
| Nacht 23–4 Uhr | kein Tempobonus mehr (Faktor 1,000; v0.4: +15 %, Ø Wunschtempo neuer Autos 129,1 → 147,8 km/h) |
| Wunschtempo | Autobahn 12:00: Pkw ab 114,5, Lkw 81,3–88,5 km/h (v0.4: Lkw ≥ 110,4); Ø neuer Autos trocken 123,5 · Regen 100,8 · Schnee 76,0 km/h |
| Verfolgung | Dichte × 0,20 (−80 %); sichtbare Autos 8,2 → 1,3 (15 s nach Beginn, Spieler 225 km/h) |
| City Limits | × 2,5 gegenüber der Stadtstraße (14 Fz/km um 12:00 auf 2 Spuren = 2,5 × so viel je Spur wie Autobahn) |
| sichtbare Autos (Spieler 160 km/h) | 08:00 12,1 · 03:00 2,3 · City (80 km/h) 10,2 |
| Rollende Sperren | Landstraße 17:00, Spieler 90 km/h, 120 s: längstes Nebeneinander gleich schneller Autos 0 s (ohne die Regeln 72 s); erlaubt bleibt nur das Elefantenrennen der Lkw auf 3+ Spuren |
| Sicherheit | 0 Überlappungen, 0 Autos tauchen im Bild auf/verschwinden, stehender Spieler: 0 Treffer bei 46 Autos |
| Spurwechsel | 12 in 60 s (12:00), jeder mit Blinker 1,0–1,5 s vorher (`test_lane_changes_are_signalled`) |

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

Regen × 0,898, Schnee × 0,741 (√Kurvenhaftung seit v0.5.0; v0.4: × 0,938 / × 0,849): z. B. schärfste Kurve Kurvigkeit 2
bei Schnee 108 (GT) – 123 km/h (Kompakt), Bergstraße (Kurvigkeit 3) 77–87 km/h.
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
(≤ 165 km/h Schnitt, seit dem QA-Review v0.5.0 aus der Zusammensetzung der Etappe: auf den längsten Etappen bis
172 km/h) liegen weit unter dem besten idealen Schnitt jeder Etappe (mindestens 207 km/h, Saragossa – Pau).

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
ideale Schnitt liegt auf jeder Etappe bei mindestens 207 km/h ((i0)). Keine Anpassung nötig – seit dem QA-Review v0.5.0
doch: die Starteinträge folgen der Zusammensetzung der Etappe (Nachtrag am Ende von (j)).

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
| v0.5.0 – Bremsung des Wetters (Regen 15,2, Schnee 9,7 m/s²), Kurvenhaftung 0,81 / 0,55 | | | |
| Gran Turismo, Regen + Nacht | – | – | **0** von 104 (+59 m, Budapest – Wien km 185,6) |
| Gran Turismo, Schnee + Nacht | – | – | **0** von 104 (+28 m, Saragossa – Barcelona km 178,8) |
| Review: Schnee nachts 338 statt 248 m Sicht (für den Verkehr, (i6)) | | | |
| Gran Turismo, Schnee + Nacht (338 m) | – | – | **0** von 104 (+28 m, dieselbe Kurve hinter einer Kuppe: 89 m Sicht, unabhängig vom Nebel; danach +34 m, Budapest – Wien km 185,5) |

Mit der halben Bremsung im Schnee bleibt bei Nacht nur eine knappe Reserve – die Sicht bei Schnee darf nicht sinken; für
den Verkehr musste sie steigen ((i6), „Wetter“).

Ohne Schilder sind Kurven direkt hinter Kuppen die Falle (die Straße dahinter ist verdeckt, z. B. 153-km/h-Kurve erst
84 m vorher sichtbar). Daher stehen Warnschilder vor scharfen **und vor blinden** Kurven (renn-modul.md §4) – jetzt auch
in den City Limits (dort gibt es kein Radar) und vor Kurven, die ein Abschnittswechsel abschneidet. Mit Kurvigkeit 1 =
0,30 sind mehr Autobahnkurven scharf und damit beschildert; im Tunnel gilt trockene Haftung.

**(i6) Sichtprüfung Verkehr** (Review v0.5.0, `curve_sight.gd --traffic`, `sight_check.gd check_traffic`, alle 52
Etappen in beiden Richtungen, alle 15 m): Kommt der Spieler hinter dem langsamsten Verkehr des Wetters zum Stehen,
sobald er ihn sieht? An jedem Punkt steht das langsamste Fahrzeug, das dort fahren kann (`TrafficSystem.slowest_speed_kmh`:
Pkw sowie Lkw/Busse am vorsichtigen Ende ihres Bereichs, mit Tempolimit, City Limits und Wetter, × 0,9 für Kolonnen –
im Schnee in den City Limits 21 km/h, auf der Autobahn Lkw 49 km/h) in seiner Spur, alle anderen Spuren sind zu.
Gesehen ist es, sobald der Renderer sein Heck mit halber Deckkraft zeichnet (Kamera-Abstand ≤ 0,84 × Sicht, Tunnel:
360 m) und – mit Kuppen – die halbe Fahrzeughöhe (Pkw 0,75 m, Lkw/Bus 1,9 m) aus der Kamera zu sehen ist. Der Spieler
kommt mit Höchsttempo aus der vorigen Kurve (Profil wie (i5), Kurven bis 5 % über der Grenze), reagiert nach 1 s und
bremst voll im Wetter (Tunnel trocken, wenn beide drin sind). Reserve = Abstand beim ersten Sehen − (v_rel · 1 s +
v_rel² / 2a + 2 m). Nur Nebel (das, was das Wetter entscheidet), Gran Turismo (schnellstes Auto):

| Fall | Sicht | kleinste Reserve |
|---|---|---|
| Schnee, Nacht, vor dem Review | 248 m | **−47 m** (jede Etappe: Kolonne an den City Limits, 235 → 21 km/h braucht 243 m, gesehen bei 196 m) |
| Schnee, Nacht (jetzt) | 338 m | **+27,5 m** (gesehen bei 271 m) – auch mit Höchsttempo an jedem Punkt statt Profil +27,5 m |
| Schnee, Dämmerung 19:30 | 377 m | +44,8 m (Hamburg – Hannover, Kamera im Tunnel: 360 m) |
| Schnee, Tag | 450 m | +42,4 m (dieselbe Tunnelausfahrt) |
| Regen, Nacht | 322 m | +50,6 m |
| Regen, Tag | 585 m | +80,9 m |
| trocken, Nacht / Tag | 495 / 900 m | +110,8 / +140,1 m |
| Sportwagen, Schnee, Nacht | 338 m | +52,9 m |

**Kuppen** sind davon unabhängig: auf hügeligen Etappen liegt ein Auto hinter einer Kuppe teils erst 55–90 m vor dem
Spieler im Blick (die Hügel sind optisch doppelt so hoch, `render.hill_height_scale`). Aus vollem Tempo reicht das bei
keinem Wetter, auch trocken am Tag nicht und auch in v0.4.0 nicht – dort hilft nur Ausweichen oder vor einer blinden Kuppe
vom Gas zu gehen. Anteil der Straßenpunkte, an denen ein Fahrzeug der langsamsten Klasse hinter einer Kuppe zu spät
auftauchte (Gran Turismo, Profil; „v0.4.0“ = Bremsung 70 km/h/s bei jedem Wetter und Verkehr von v0.4.0):

| Wetter (Gran Turismo) | v0.4.0 | v0.5.0 (nach dem Review) |
|---|---|---|
| trocken, Tag | 0,46 % der Punkte (schlimmster −103 m) | 0,63 % (−103 m) |
| Regen, Nacht | 0,63 % (−99 m) | 1,35 % (−126 m) |
| Schnee, Nacht | 0,54 % (−81 m) | 3,11 % (−152 m) |

Schnee macht Kuppen gefährlicher (halbe Bremsung, langsamer Verkehr) – das gehört zur gewünschten Schwierigkeit, mehr
Sicht im Nebel ändert daran nichts. Dass alle Spuren hinter einer blinden Kuppe zugleich mit langsamem Verkehr belegt
sind, ist selten – aber es kommt vor: Die Fahrer-Simulationen des Reviews (unten) fanden es nach den Korrekturen nicht
mehr, die QA danach mit einem eigenen Fahrer-Bot auf rund 4 700 km Schnee (≈ 2,9 h mit Höchsttempo) dreimal ohne Ausweg
(Saragossa – Pau km 147,1 um 07:30 erst bei 73 m statt 118 m gesehen, um 19:30 bei 75 statt 83 m, km 75,8 bei 102 statt
106 m) und einmal unvermeidbar: City Limits Burgos, Schnee 22:18, 213 km/h, eine Kolonne mit 28–34 km/h auf beiden
Spuren erst 152 m vorher sichtbar, nötig 174 m – Aufprall mit 98 km/h trotz Vollbremsung. **Seitdem (QA-Review v0.5.0)
steht vor jeder blinden Kuppe ein Warnschild „Kuppe“** (renn-modul.md §4 „Kuppenschilder“: verdeckt die Kuppe ein
Fahrzeug innerhalb 180 m – etwa der Anhalteweg im Schnee aus 200 km/h Annäherung –, steht 150 m vor der Stelle das
Schild; im Netz 5,4 je 100 km, an allen QA-Stellen – Burgos km 208,5, Saragossa – Pau km 147,1 und 75,8 – davor). Wer
wie vor einer blinden Kurve vom Gas geht, kommt
rechtzeitig zum Stehen; die optische Überhöhung der Hügel bleibt (flachere Hügel nur in den City Limits verbesserten
die schlimmste Stelle dort nur von −97 auf −74 m Reserve).

Menschlicher Fahrer (Review-Skript `fair_sim.gd`: Gran Turismo mit Höchsttempo, sieht nur, was das Bild zeigt – Nebel
ab halber Deckkraft, Kuppen –, reagiert nach 0,8 s auf ein Auto, das auftaucht oder in seine Spur zieht, bremst voll im
Wetter, weicht nur in sichere Lücken aus; Kassel – Würzburg, Hamburg – Hannover, Saragossa – Pau = 618 km je Lauf):

| Lauf (618 km je Zeile, wo nicht anders angegeben) | vor dem Review: Kollisionen / zu spät gesehen | jetzt |
|---|---|---|
| Schnee 19:30 | 2 / 5 (Kolonne an den City Limits Würzburg aus dem Nebel; Kuppe Saragossa – Pau km 147) | **0 / 0** |
| Schnee 02:00 | – | **0 / 0** |
| Schnee 07:30 und 17:00 | 0 / 0 | **0 / 0** |
| Sportwagen, Schnee 19:30 | – | **0** / 1 (dieselbe Kuppe km 147: gesehen bei 121 m, ausgewichen) |
| 5 hügelige Etappen, Schnee 06:00 und 21:00 (2 892 km) | 0 / 0 | **0** / 1 (Kuppe in den City Limits von Sofia, 119 m, ausgewichen) |
| trocken und Regen, 07:30 und 19:30 | 1 / 0 (trocken 07:30: der Fahrer zog selbst in ein blinkendes Auto) | unverändert |

Ein Auto, das vor dem Spieler einschert, kam in keinem Lauf zu spät (Untergrenze, Abschnitt „Verkehr als Hindernis“).

**(j) Schwierigkeit vorher/nachher** (v0.5.0 nach dem Review – Regen- und Schneezeilen neu gemessen, trocken
unverändert; `difficulty_sim.gd`): Stand v0.4.0 gegen v0.5.0, je Zeile die drei Etappen Kassel – Würzburg (Autobahn
mit Limits), Saragossa – Pau (Autobahn und Bergstraße) und Hamburg – Hannover (dichte Autobahn) in einer Richtung mit
der Limousine, Tank voll, ohne Polizei: 558 km außerhalb und 59 km in den City Limits. Fahrer: **naiv** = Vollgas,
bremst nur für Kurven und weicht aus (Nachbarspur mit dem meisten Platz, wenn seine
in ~2,2 s zu ist), nie für Autos – sind alle Spuren innerhalb seines Bremswegs zu, kracht es; **spät** = derselbe, bremst
aber im letzten Moment wie auf trockener Straße (70 km/h/s nach 0,3 s) – ein Spieler, der sich nicht aufs Wetter
einstellt; **Autopilot** = der echte Autopilot (immer vmax, Radar ignoriert). „Alle Spuren zu“: Anteil der Zeit, in der in
jeder Spur ein Auto innerhalb des Anhaltewegs eines Autos mit Höchsttempo ist ((v − v_Auto)²/2a + (v − v_Auto) · 1 s
+ 10 m, a = Vollbremsung im Wetter; v0.4.0 bremste bei jedem Wetter mit 19,4 m/s²) – ohne Bremsen kein Vorbeikommen;
in Klammern solche Situationen je 100 km. Annäherung = Tempounterschied zu jedem überholten Auto (naiver Fahrer).

Außerhalb der City Limits:

| Wetter, Uhrzeit | Annäherung km/h: Median (p10–p90) | alle Spuren zu: % der Zeit (je 100 km) | Spurwechsel/km | Kollisionen/100 km: naiv | spät | Autopilot | Autopilot Ø km/h | Verkehr Median km/h: Pkw (Lkw) |
|---|---|---|---|---|---|---|---|---|
| trocken 07:30 | 109 (56–135) → **112** (61–149) | 7,6 (7,0) → **15,0** (12,4) | 0,14 → **0,16** | 1,8 → **4,1** | 0,0 → **0,0** | 0,0 → **0,0** | 156 → **143** | 124 (111) → **102** (84) |
| trocken 00:30 | 83 (64–110) → **123** (71–158) | 0,2 (0,2) → **0,7** (0,9) | 0,01 → **0,02** | 0,0 → **0,5** | 0,0 → **0,0** | 0,0 → **0,0** | 204 → **194** | 150 (135) → **105** (85) |
| Regen 07:30 | 100 (53–126) → **117** (65–150) | 6,6 (6,1) → **19,5** (14,9) | 0,13 → **0,20** | 1,8 → **3,9** | 0,0 → **0,0** | 0,0 → **0,0** | 154 → **132** | 122 (112) → **90** (74) |
| Regen 00:30 | 81 (66–108) → **123** (80–159) | 0,0 (0,0) → **0,4** (0,9) | 0,01 → **0,02** | 0,0 → **0,2** | 0,0 → **0,0** | 0,0 → **0,0** | 196 → **183** | 154 (128) → **94** (76) |
| Schnee 07:30 | 78 (45–105) → **117** (57–151) | 2,3 (2,3) → **20,6** (16,7) | 0,10 → **0,22** | 1,4 → **3,4** | 0,0 → **1,8** | 0,0 → **0,0** | 152 → **114** | 124 (112) → **71** (56) |
| Schnee 00:30 | 68 (41–123) → **120** (69–148) | 0,0 (0,0) → **0,3** (0,4) | 0,01 → **0,02** | 0,0 → **0,2** | 0,0 → **0,2** | 0,0 → **0,0** | 180 → **166** | 140 (131) → **71** (55) |

City Limits (zweispurig, 2,5-fache Dichte – dort entscheidet vor allem die Dichte, das Wetter macht den Verkehr langsamer):

| Wetter, Uhrzeit | Annäherung km/h: Median (p10–p90) | alle Spuren zu: % der Zeit (je 100 km) | Spurwechsel/km | Kollisionen/100 km: naiv | spät | Autopilot | Autopilot Ø km/h | Verkehr Median km/h: Pkw (Lkw) |
|---|---|---|---|---|---|---|---|---|
| trocken 07:30 | 112 (67–161) → **100** (64–180) | 79,1 (22,0) → **84,0** (11,8) | 0,47 → **0,61** | 22,0 → **22,0** | 0,0 → **0,0** | 0,0 → **0,0** | 59 → **65** | 52 (46) → **47** (38) |
| trocken 00:30 | 179 (139–194) → **187** (147–196) | 8,0 (6,8) → **8,2** (5,1) | 0,12 → **0,03** | 1,7 → **5,1** | 0,0 → **0,0** | 0,0 → **0,0** | 137 → **196** | 62 (54) → **47** (–) |
| Regen 07:30 | 127 (62–185) → **108** (51–163) | 78,5 (20,3) → **81,9** (11,8) | 0,64 → **0,49** | 22,0 → **27,1** | 0,0 → **0,0** | 0,0 → **0,0** | 60 → **54** | 52 (50) → **39** (35) |
| Regen 00:30 | 170 (114–185) → **171** (138–194) | 2,6 (5,1) → **11,4** (5,1) | 0,05 → **0,07** | 0,0 → **1,7** | 0,0 → **0,0** | 0,0 → **0,0** | 207 → **182** | 60 (86) → **41** (–) |
| Schnee 07:30 | 110 (63–154) → **97** (52–170) | 57,6 (25,4) → **80,9** (11,8) | 0,37 → **0,56** | 23,7 → **23,7** | 0,0 → **5,1** | 0,0 → **0,0** | 54 → **41** | 51 (37) → **30** (30) |
| Schnee 00:30 | 146 (113–159) → **160** (141–183) | 0,9 (1,7) → **11,4** (6,8) | 0,10 → **0,07** | 0,0 → **0,0** | 0,0 → **0,0** | 0,0 → **0,0** | 193 → **129** | 58 (54) → **34** (–) |

Summe aller Läufe (3706 km je Fahrer): naive Kollisionen 1,86 → **3,13** je 100 km, mit Spätbremsen 0,00 → **0,38** (14 von 14 bei
Schnee), Autopilot 0 → **0** (auch kein Bankett: 0,0 s, kein Untersteuern: max 0,00). Im Berufsverkehr (07:30) außerhalb
der City Limits sind alle Spuren trocken 2,0-, bei Regen 3,0- und bei Schnee 9,1-mal so oft zu wie vorher; der naive Fahrer
überholt trocken 293 statt 238, bei Schnee 333 statt 196 Autos; je 100 km zieht 4,5-mal ein Auto vor ihm heraus (v0.4.0:
nie; Autopilot 0,0–2,3-mal), Lkw fahren 28 s nebeneinander (Elefantenrennen, Regen/Schnee 13/11 s; v0.4.0: 0).
Der Autopilot bleibt kollisionsfrei und ist gegenüber v0.4.0 trocken 8/5 %, bei Regen 14/7 % und bei Schnee
25/8 % langsamer (07:30/00:30).

Ganze Etappen und Rennen mit dem Autopilot (v0.5.0 vor dem Review, `run_stage.gd`/`run_race.gd`, Wunschtempo 235 km/h,
Radar befolgt, Tanken nach Bedarf) – alle ohne Kollision, Leitplanke und Untersteuern, neben der Fahrbahn nur in der
Tankspur (höchstens 0,9 s):

| Etappe | Auto | Wetter, Start | Ø km/h |
|---|---|---|---|
| Hamburg – Hannover | Gran Turismo | Schnee, 08:00 | 98,4 |
| Dortmund – Frankfurt | Limousine | Schnee, 07:30 | 82,3 |
| Bremen – Dortmund | Kombi | Schnee, 17:00 | 93,3 |
| Saragossa – Pau | Sportwagen | Schnee, 12:00 | 107,5 |
| Kassel – Würzburg | Kompakt | Regen, 17:00 | 102,7 |
| Hamburg – Bremen | Limousine | Regen, 08:00 | 100,3 |
| Saragossa – Pau | Kombi | Regen, 00:30 | 155,8 |
| Kassel – Würzburg | Limousine | trocken, 08:00 | 125,4 |

Kiel – Nürnberg (Limousine, Rennwetter und Tageszeiten aus dem Rennen): **27:05,5** (v0.4.0: 25:03,8) – Schnee auf der
ersten Etappe (74 km/h mit Pflicht-Tankstopp), Regen auf der zweiten (146 km/h, nachts), sonst trocken 137–165 km/h.
Nach dem Review (die Tutorial-Etappe ist jetzt immer trocken; `run_race.gd --race-seed`, Limousine, beide fehlerfrei,
0 Kollisionen): Kiel – Nürnberg mit Renn-Seed 63352 **29:39,1** – Kiel – Hamburg trocken 97 km/h (Pflicht-Tankstopp),
Hamburg – Hannover trocken nachts 157, Hannover – Kassel 138, **Kassel – Würzburg Schnee ab 23:07 Uhr 143 km/h** (Nacht,
wenig Verkehr), **Würzburg – Nürnberg Schnee ab 12:35 Uhr 82 km/h**; München – Bremen mit Renn-Seed 95028 **28:41,7** –
Regen auf der ersten Etappe (München – Nürnberg 112 km/h), sonst trocken 128–161 km/h.
Bei diesen Läufen gefunden und behoben: (1) der Autopilot zog 700 m vor der Tankspur quer über alle Spuren – im Schnee
in ein 95 km/h langsameres Auto in der Mittelspur (Saragossa – Pau, Sportwagen); jetzt Spur für Spur in freie Lücken
(renn-modul.md §10, `test_fuel_lane_approach_waits_for_a_gap`). (2) Ein Auto, das einem Lkw nicht zügig vorbeikam,
pendelte an der Grenze des Seitenfensters genau neben dem Spieler – im Schnee 52 km Kolonne mit 53 km/h; jetzt
Haltefenster und Tempo-Abstände nach Wetter (Abschnitt „Verkehr“, `test_yielding_car_does_not_hover_beside_the_player`).

Bestenlisten: Die Starteinträge (`leaderboard.seed_avg_kmh` 125–165 km/h) liegen bei trockenem Wetter weiter im Bereich
des vorsichtigen Autopiloten (125–165 km/h je nach Tageszeit, Verkehr und Tankstopp) – gute Spieler schlagen sie; bei
Regen (100–156 km/h) und Schnee (74–108 km/h) sind sie ein hohes Ziel, wie es zum Wetter passt.

Nachtrag (QA v0.5.0): Auf der Tutorial-Etappe Kiel – Hamburg waren sie unerreichbar – Rekord 2:52,73 nur 4 % über der
Zeit des schnellsten Autos ganz ohne Verkehr (Sportwagen bei vmax 166,6 s), der 10. Platz 3:46,11 rund 25 % schneller
als der Autopilot im Verkehr um 08:00 (4:43–5:30); auch kurze Etappen um 110–125 km lagen am Tag außerhalb der Top 10
(Würzburg – Nürnberg trocken 12:25: 121 km/h). Ursache: dieselben 125–165 km/h auf jeder Länge, obwohl jede Etappe mit
20 km City Limits endet und das Tutorial einen Pflicht-Tankstopp hat. Jetzt aus der Zusammensetzung (docs/daten.md
„Starteinträge“): City Limits mit `seed_city_kmh` (60–80), der Rest so schnell, dass die typische Etappe
(`seed_ref_km` 235 km) unverändert bleibt, + `seed_fuel_stop_s` (35 s) je Etappe mit teilgefülltem Tank + Fährzeiten.
Kiel – Hamburg: Rekord 3:52,9, 10. Platz 4:55,2 (Rückrichtung ohne Tankstopp 3:17,9 / 4:21,9); 110–150 km 6–11 %
langsamer, 210 km unverändert, 365–395 km 3–4 % schneller; Kiel – Nürnberg 24:02,2 … 31:18,8, Königsrennen mit Fähre
4:39:02,6 … 6:05:15,4 (Test `test_seed_entries_follow_the_stage_make_up`).

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
- **Renn-Modul (v0.5.0)**: `traffic.update` mit `ctx.weather` und `ctx.brake_mps2 =
  vehicle.brake_decel_mps2(Wetterhaftung)` – auch im Tunnel die Haftung des Wetters, nicht die trockene unter dem Wagen
  (Review: sonst zieht hinter der Tunnelausfahrt ein Auto mit der trockenen Untergrenze heraus); ohne sie fährt der
  Verkehr trocken und rechnet beim Einscheren mit 70 km/h/s; Blinker zeichnen aus `Car.signal_dir`/`signal_age` (View `blink`/`blink_t`, renn-modul.md §8). Ein
  Autopilot oder Bot, der mit festen 15 m/s² plant oder proportional lenkt, kommt im Schnee nicht mehr unfallfrei
  durch – `Autopilot.plan_decel`/`steer_to` nutzen.
- **Audio/HUD (Wetter)**: der Wagen rutscht nach Spurwechseln sichtbar nach (`lat_speed` klingt mit
  `vehicle.steer_response_s(Haftung)` ab) – ein Rutschgeräusch dafür gibt es noch nicht.
