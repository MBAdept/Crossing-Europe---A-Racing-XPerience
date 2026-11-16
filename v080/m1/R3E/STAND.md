# R3E – STAND (Übergabe)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-2
- Branch: worktree-wf_c23ec0b9-e7b-2 (Sicherung: origin wip/v080-r3e, nach jedem Commit pushen)
- Basis: 4d02ada (R3 final head), ff-merge done, .godot kopiert, Import gelaufen.
- NACH NEUEM class_name: `godot --headless --path . --import` (sonst "Identifier not found").

## Erledigt (Commits 8e4ad83, da415bf, b4d21a1, 00f2102, 25daca8 – gepusht)
- vehicle_standin.gd, vehicle_sprite.gdshader (2 Durchgänge; Faltung mit Bodenschürze; Verkehrsbild NICHT mehr
  gezogen – onto_road legt Zeilen unter der Bodenlinie entlang des Sehstrahls auf die Straße; albedo_for gibt den
  Anzeigewert wie Arcade aus), vehicles.gd (Sprite-Zweig, boxtex, Flares, Arcade-Licht), Schnappschuss lod "box".
- Render-Check check_vehicle_standin 6/6 OK (spieler 0,0 px/2–3 px/+0,8 −0,8 +2,7 %; verkehr 2/2/1 px; kasten 3 px;
  nacht: kombi −6,0 %, van_white 20 m −3,6 %, 60 m −1,8 %; verdeckt 0 px Tag+Nacht; laden 71→71).
- Unit 73/0 (Filter vehicle). check_vehicles leistung 40,9 µs (Last 9 auf 4 Kernen!) – nachmessen.
- Bildserie (vor 25daca8!) in deliver/R3E 01–20 – NEU RENDERN (Shader geändert).

## Befunde für den Bericht
- Renderer-weit: dunkles Ende im 3D-Pfad dunkler als Arcades Leinwand (Spielerbild pixelgleich, Tag wie Nacht:
  11→7, 19→16, 28→26,5, ab ~56 exakt) – R1 melden (Puffer-Präzision / Umrechnung). Roter Sportwagen nachts −11 %.
- Arcade-Rundungsfehler BoxVehicle.emit (Heckfläche fehlt bei Bus 60,3 m) – eingefroren, melden.
- Kastenwerfer + eingebackener Schatten → Doppelschatten, sobald R1s Straße Schatten empfängt.

## FERTIG (10:30) – Kopf fbfd1b5 = origin wip/v080-r3e, Arbeitsbaum sauber
- Voller Lauf #2 (fbfd1b5): bestanden (603 Unit-Tests 0 Fehler, 73 CHECK OK, leistung 36,4 µs).
- golden.sh check: 20 von 20 identisch. run_render_checks.sh modern: 6 von 6 Dateien, 26 RENDER-CHECK OK.
- bericht.md + 20 Bilder in deliver/R3E. Scratch aufgeräumt (xdg*, mesa, shots, series-PNGs gelöscht).
- Offen nur: StructuredOutput an den Lauf zurückgeben.

## Vorher (10:20)
- Voller Lauf #1 (25daca8): 603 Unit-Tests 0 Fehler, alle CHECK-Dateien OK außer check_vehicles leistung 48,9 µs
  (bimodal: 35,6–39,7 OK oder ~49 µs mit p90 ~62 – VM/Kern-Konkurrenz). Gates danach abgebrochen.
- Optimierung fbfd1b5 (Flare-Frühausstieg bei dunklen Lampen, gepusht): Filterlauf vehicle grün, leistung 35,6 µs.
- final_gates2.sh läuft (final_gates2.log): run_tests #2 (letzter erlaubter), golden check, render checks modern.
- NICHTS im Worktree ändern, bis FERTIG.

## Vorher (09:50)
- Serie neu gerendert (series3.sh, 30 Bilder, Stand 25daca8), deliver.py → deliver/R3E 01–20, angesehen: gut.
- Bus-Bilder mit Bildunterschrift 58 m neu zusammengesetzt (recompose.sh).
- final_gates.sh läuft (Log final_gates.log): Bench (Bild 40,1/41,0/39,0 gegen Kasten 36,5/32,4/34,9 µs),
  leistung x3 38,7/39,0/39,7 OK, dann run_tests.sh (voll, 1. von max. 2), golden.sh check, render checks modern.
- Doku 10.8 nach 25daca8 ergänzt (albedo_for, Grenzen dunkles Ende, Leistung) – noch nicht committet (nur Doku).
- bericht.md fast fertig: fehlen PRUEF_TABELLE, CHECK_VEHICLES_ZEILE, GATES_ZEILE.

## Als Nächstes
1. Gates abwarten; Ergebnisse in bericht.md; Doku committen + pushen.
2. STAND; Aufräumen (xdg*, mesa, shots/, series PNGs, xdg_final).
3. StructuredOutput.

## Werkzeuge (Scratch)
- ab_inject.sh / ba_inject.sh, tools/make_series*.py, series.sh, series2.sh, tools/deliver.py, crop_ab.py, crop2.py,
  side.py, night_regions.py, transfer.py, transfer2.py, pull_table.py, probe/bench_standin.gd

## Fallstricke
- Bash-Tool lehnt komplexe Befehle/Heredocs ab: Python-Hilfsskripte unter tools/ im Scratch.
- NICHT am Code editieren, während eine Bildserie läuft.
- depth_prepass_alpha landet NICHT in der Tiefentextur (deshalb 2 Durchgänge).
- VM geteilt (andere Pakete rendern): Leistungsmessungen schwanken stark.
