# AS1b – Stand (Übergabe)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_2e14ac26-9d4-2
- Branch: worktree-wf_2e14ac26-9d4-2 (gepusht als origin wip/v080-as1b)
- Basis: d025d1d (ff-merge erledigt), _cache3d von AS1 kopiert, .godot kopiert + Import gelaufen
- Helfer (scratch): cycle.sh "<glob>" [sheet] = export+bake+import+manifest(+Kontaktbogen); Godot-Glob nur * und ?
  tools/models/prop_scene.sh <png> --models=a,b [--mode=dist|lods|road] (eigenes, committetes Werkzeug;
  verschoben aus tools/ in tools/models/, damit es in der Dateihoheit liegt)
- Wegwerf-Worktree für A/B: scratch/abwt, Zweig as1b-ab-tmp = origin/wip/v080-r2 (b947e73) + mein Zweig gemergt,
  enthält eine PROBE-Änderung an vpbr.gdshader (Rotor). NIE pushen; am Ende löschen (git worktree remove + branch -D).

## Befunde (gelesen)
- Kiel–Hamburg ab Kiel, erste 75 km (scratch stage_sets.gd): tree_oak 147, tree_birch 88, bush_round 76,
  haybale 48, wind_turbine 28, farmhouse 7, fuel_pump 9, fuel_station 1, radar_camera 2, object:fuel_pylon 1
  (prozedural, R6). Liste vollständig; bush_low, barn, windmill, power_pylon, streetlight, delineator,
  customs_booth kommen in den ersten 75 km NICHT vor.
- R2 props.gd: graphics.modern.props.bend_cover. Bodendecker-Sets: props/cover_bush, props/cover_grass.
- vpbr (R3): Rotor -> Lackcode 0.875 + UV2.y = Nabenhöhe/128 m (gebaut, Prüfer kennt ihn); Drehung erbitten.
- leaves.gdshader (R2): kein Schnee/Nässe -> melden. vpbr-Lampe zeigt tagsüber halbe Leuchtfarbe -> Scheiben
  mit dunkel-warmer Leuchtfarbe #7a5e3a, Gewicht 0.55-0.9.

## Erledigt (gepusht)
- 3598926: Bäume, Büsche, Bodendecker, Prüfer + test_model_db (modern_only), Prüfszene.
- 2b29543: Baumeister "building", farmhouse, haybale, wind_turbine (Rotor-Code), Hooks WINDOW_LOG + hub_subdiv.
- 56b7798: fuel_station/pump, radar, barn, customs_booth, windmill, delineator, power_pylon (lattice/cutout).
- Geometrieprüfung 2 (props/, nach allen Hooks): 86/86 identisch, 118 s. Prüfer: CHECK models OK.
- A/B S1–S3 (abwt, R2 + mein Zweig): keine Sprite-Platzhalter; Bilder in deliver/AS1b.
- 9c34dca: Doku §14, Prüfszene nach tools/models/prop_scene.{gd,sh} verschoben (Dateihoheit).
- --check-keys OK (zweimal, auch nach der Laterne). Determinismus: alle 21 props --force, 369 s, git status leer.
- adff0b3: Laterne hidden_tops (Anker dir (0.007,-1,0) statt seitlich), 274 Dr., zweimal byte-identisch.
- bericht.md in deliver/AS1b fast fertig (Platzhalter nur noch Tests/Golden).

- run_tests.sh (1. Lauf): 576 Tests, 0 fehlgeschlagen, 73 CHECK OK, 569 s, Exit 0.
- abwt-Worktree + Zweig as1b-ab-tmp gelöscht (nie gepusht); Scratch-Bilder gelöscht (15 MB übrig).

- golden.sh check: 20 von 20 identisch (159 s). Arbeitsbaum sauber, HEAD adff0b3 = origin/wip/v080-as1b.
- bericht.md fertig: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1b/bericht.md

## Als Nächstes
Paket fertig – nur noch StructuredOutput. Offene Punkte für andere Pakete: bericht.md §10/§11.

## Fallstricke
- BC3-Alpha quantisiert: Halo-Alpha <= 0.30 (Laub, Schwelle 0.42) bzw. <= 0.33 (cutout, 0.5)
- git: keine verketteten Befehle/Heredocs mit cd außerhalb (Werkzeug lehnt ab); Commit-Text per Datei
- Karten: flach + viele (Zelte kräuseln sich an der Silhouette, Paare streifen)
- delaunay_2d_cdt füllt nur gegen den Uhrzeigersinn gegebene Polygone (ccw() erzwingt es)
- AO-Baker legt eigenen Bildknoten an: AO zuletzt backen (sonst landet die Emission im falschen Bild)
- Kommentaränderung in veg3d.py/props3d.py ändert den Cache-Schlüssel (Dateihash), nicht das Ergebnis

## Scratch
- /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1b/
