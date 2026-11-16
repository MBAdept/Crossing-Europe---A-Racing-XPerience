# RINT-A STAND (Übergabe)

Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_c23ec0b9-e7b-1
Branch:   worktree-wf_c23ec0b9-e7b-1  (Sicherung: origin wip/v080-rint-a, nach jedem Commit gepusht)
Helfer:   $S/bin/*.sh (env, import, gs, xs, xg, gh, rt, ab, ab_all, mshot, drive, warm, leak, gates), p_*.py = Patches
          (S = dieser Ordner)

## Erledigt (Commits, alle gepusht) – Kopf f9a6cd2
- Merges R1, R2, R3 (contact_shadow -> vehicle_shadow), AS1b, UI1; a27d3ed uid
- 5d0f1e4 Kern+STRICT, Gelände/Fernboden-Licht, Lampen, Rotor, Varianten, Bodendecker, Prüfungen, run_tests-Haken
- 689d087 eine Spiegelquelle; e380b50 Fernbilder blenden am Ende der Sicht aus
- 7f6dce9 leave_modern(always); AudioManager stop_all + 60 ms beim Beenden; Doku §12
- bd30c5c check_session_modern (pause/rueckfall/freigabe grün), keine Bodendecker in City Limits
- 412a756 check_vehicles lampen_fest mit Grundlinie; f9a6cd2 check_models klassen (keine Drehung), check_occlusion lkw (Verkehrskegel aus)

## FERTIG (Kopf fd27c16, gepusht nach origin wip/v080-rint-a)
- 9b4be1c: flare.gdshader (Lichtpunkte bei 75 %), props.gd warmup_nodes je Modell; fd27c16: kern_zeit misst den Kern
  (tests/race3d/fixtures/core_renderer.gd)
- Gates Endstand (gates2/): import ok, render 13/13 (39 OK), run_tests 2. Lauf 673/0 + kern_zeit rot (Umfang korrigiert,
  check_modern_stage einzeln 7/7), warm 0 Varianten, drive ok (Perf im Bericht); golden 20/20 (bd30c5c), path/sight/
  validate/ERGEBNIS aus gates/
- Bericht: deliver/RINT-A/bericht.md (gebaut mit bin/p_bericht.py aus bericht_template.md + Entwürfen)
- große Scratch-Ordner gelöscht

## Bilder (deliver/RINT-A): ab_*_hoch.jpg (12), spiegelung, rotor, bodendecker, rauten, bremslicht_150m

## Befunde fürs Ergebnis (nicht behoben, RINT-B/Lead)
- Horizont: Nebelband (Fernboden jenseits Sicht = reine Nebelfarbe) zwischen Gelände und Silhouetten, 2–7 px (S1), T4
  deutlich (wirkt wie Wasser); Arcade: Gras bis zur Horizontzeile; Silhouetten in Modern 2 px tiefer
- Nacht: Gelände/Schneeboden heller als Arcade (N1 Boden +21..42 %, Fahrbahn gleich) – R1-Lichtgesetz (Nachtboden)
- Laternen nachts: Kegel da (16 Pools), aber kein kräftiger Schein am Leuchtenkopf wie Arcade (STATIC_HALO 0,35)
- fehlend (spätere Pakete): Tankdach S2 (R6), Brücke S4 (R5), Zielportal S5 (R6), Wetterpartikel N1 (R4)

## Fallstricke
- godot --import hing einmal: abbrechen, *.ctex-XXXX löschen, neu -> 8 s
- Bash-Tool: keine verketteten git-Befehle / heredocs mit cd: Patches als Datei
- vehicles.gd/model_factory.gd/vehicle_pose3d.gd = R3E: nur Klasse vehicle_shadow geändert
- debug_snapshot addiert Zahlen gleicher Schlüssel (static_lamps 94 = 47 lights + 47 flares)
