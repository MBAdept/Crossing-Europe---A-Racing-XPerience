# AS1R – STAND (Übergabe)

Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9693abb2-cee-3
Branch:   worktree-wf_9693abb2-cee-3  (Sicherung: origin wip/v080-as1r, nach jedem Commit pushen)
Basis:    d025d1d (ff-merge done), .godot copied + import done, _cache3d copied from AS1 worktree
Kopf:     c478902 (gepusht, origin wip/v080-as1r = c478902), Arbeitsbaum sauber

## Werkzeuge (Scratch)
- bin/rebuild.sh "<glob>" [--force]  -> export + bake + manifest + validate (logs/); Bake-Glob nur * (keine [..])
- bin/sheet.sh <out.png> <contact sheet args> (--review --views=.. --clay --caster --chase=9,30 --set=..)
- bin/dump.gd + bin/ana.py clear|lamps, bin/probe.py, bin/objs_near.py, bin/pop.sh + popmeasure.py (Stufenwechsel)
- bin/deliver.sh (alle Lieferbilder -> out/raw), bin/finish_images.py (-> deliver JPGs), bin/popsheet.py (07)
- Bericht: bericht_teil*.md + repl.json -> bin/assemble.py -> deliver/AS1R/bericht.md

## Erledigt (alle Commits gepusht)
- d990054 Spieler Runde 1, 09607c8 Verkehr, b7efee4 Lkw/Werfer/Prüfer, 5ef2515 Fugen/Emblem + Doku, c478902 Doku-Zahlen
- check_sprite_geometry 187/187 identisch (1 REIHENFOLGE) 353 s; Determinismus: force export + bake -> git sauber;
  --check-keys OK; Freigang 0 Ecken (bin/ana.py clear); Stufenwechsel 40 m 6,6-9,8 %, 120 m 22-34 %
- run_tests.sh (1. und einziger voller Lauf): bestanden, 576 Unit/0, 89 CHECK OK, 228 Skripte/0, 552 s, exit 0
- golden.sh check (einmal, am Ende): 20 von 20 identisch (151 s)
- run_render_checks.sh modern check_models: 6/6 OK
- Showroom-A/B angesehen: nicht gleichwertig (Lack, Glas, Rückleuchte um die Ecke) -> showroom bleibt false

## Abgeschlossen
- Lieferbilder 01-12 in deliver/AS1R angesehen; Bericht deliver/AS1R/bericht.md zusammengesetzt (bin/assemble.py)
- Zwischenstände (out/, xdg*) gelöscht; Arbeitsbaum sauber; kein weiterer Commit nötig (Kopf c478902)

## Stolpersteine
- Bash: keine Heredocs/verketteten git-Befehle; Skripte per Write anlegen.
- lod.py steht in COMMON_CODE: Änderung -> alle Cache-Schlüssel neu (Requisiten NICHT neu exportieren, nur Fahrzeuge).
- contact sheet --set gilt für alle Modelle (Verkehr einzeln rendern).
- golden.sh check nur einmal am Ende; run_tests.sh höchstens zweimal voll (1 verbraucht).

## Scratch
- /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AS1R/
- deliver: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1R/
