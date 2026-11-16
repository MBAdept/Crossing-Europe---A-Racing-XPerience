# AS1-KRITIK – Stand (Übergabe)

- Rolle: unabhängige Kunstkritik der Fahrzeugmodelle von AS1 (kein Bauen, KEINE Commits, kein Branch).
- Quelle (nur gelesen): /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_bade9e46-06a-1 (Commit 53bcc1b)
- **FERTIG (06:31).** Bericht und 18 Bögen: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AS1-KRITIK/bericht.md
- Arbeitskopie (wt), Kacheln (out/tiles), Netz-Abzüge (out/dump), xdg wurden gelöscht (Platz).
- Werkzeug zum Wiederverwenden: tools_kritik/ (kritik_render.gd, kritik_dump.gd -> in tools/kritik/ einer Kopie legen;
  run_jobs.sh erwartet die Kopie unter ./wt), Jobskripte jobs_*.py, Bogenskripte sheet_*.py, Auswertungen
  mesh_analysis.py, shimmer.py, lamps_x.py, silhouette.py. Zahlen in out/*.txt, Notizen out/notizen.md.
- Fallstricke: Godot-Wicklung im Uhrzeigersinn = Vorderseite; Modern Gier +a == Sprite-Zelle "l<a>";
  Kompakt-Sprite hat supersample 1.9 (nicht 1.65); erster Knick-Test (Quader) war falsch – Grundriss-Raster zeigt
  kollisionsfrei bis 60°.
