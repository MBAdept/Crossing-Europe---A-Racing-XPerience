# UI1 – Stand (Übergabe für einen Nachfolger)

**PAKET FERTIG** – Ergebnis abgegeben (Bericht: deliver/UI1/bericht.md). Ein Nachfolger muss nichts weiter tun.

- Worktree (AKTUELL, Nachfolger 1): /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9693abb2-cee-2
- Branch: worktree-wf_9693abb2-cee-2, Kopf 3b89a33, Sicherung: origin wip/v080-ui1 (nur normaler Push)
- Vorgänger-Worktree (NICHT anfassen): .claude/worktrees/wf_bade9e46-06a-3, Kopf d46a06b
- Scratch: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/UI1/
  (tools/ = Hilfsskripte: gd.sh, shot.sh, screens.sh; shots/ = Arbeitsbilder; run_tests_{1,2}.log, golden.log)
- Lieferordner: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/UI1/

## Erledigt
- Vorgänger-Commits 49a8ff7, d46a06b geprüft; AS1 (53bcc1b) und AU-B (8414002) gemergt.
- 8ba5306 Absturz-Frage, gfx in Einträgen, test_gfx_ui · a8d3e63 check_options_tabs 10/10, check_benchmark 8/8 ·
  834d7c6 Showroom3D, test_showroom, check_showroom 7/7 · cba1eef Vorschaubilder-Werkzeug · f63a9c2 Attract Modern ·
  326ac1d Doku · 940f44b Render-Prüfung Showroom 6/6, AgX · 3b89a33 Doku.
- run_tests.sh: Lauf 1 (326ac1d) bestanden 669 s, Lauf 2 (940f44b) bestanden 616 s; golden.sh check 20/20 (940f44b).

## Offen (für Lead / spätere Pakete, steht im Bericht)
- Vorschaubild Modern nach dem Renderer-Merge neu erzeugen (tools/gfx_previews.sh).
- check_options_tabs + check_attract*(--graphics=modern) in run_tests.sh einhängen (Integration).
- Showroom wird aktiv, sobald das Manifest showroom: true setzt (AS1R).

## Fallstricke
- Der Harness lehnt zusammengesetzte Shell-Befehle mit Heredoc + weiteren Befehlen ab – Skripte in scratch/tools.
- Arcade-Start darf nichts aus scripts/race3d, scripts/audio/modern, model_db.gd laden (check_arcade_lean).
- Neue class_name-Skripte: erst `godot --headless --import`, sonst kennt der Klassen-Cache sie nicht (Parse-Fehler
  in Tests) und die .uid-Dateien fehlen.
- Unter Xvfb mit 1280×720-Bildschirm wird ein 1920×1080-Fenster nicht wirklich größer (Streckfaktor bleibt 1):
  für 1080p-Bilder SCREEN=1920x1080 nutzen, in Prüfungen content_scale_factor.
