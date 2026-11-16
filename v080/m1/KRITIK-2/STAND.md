# STAND KRITIK-2 (read-only art review of AS2a cars) – FERTIG

- Rolle: unabhängige Kunstkritik der Pkw-Modelle von AS2a (keine Commits, kein Branch, nichts im Arbeitsbaum geändert).
- Quelle (nur gelesen): /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-1 @ 19aa138
- **FERTIG (~11:20).** Bericht + 20 Bögen:
  /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/KRITIK-2/bericht.md
- Gelöscht (Platz): Arbeitskopie wt/, Kacheln out/tiles/, Netz-Abzug out/dump/, xdg/ (Shader-Cache).
- Werkzeug zum Wiederverwenden: tools_kritik/ (kritik_render.gd, kritik_dump.gd -> tools/kritik/ einer Kopie;
  run_jobs.sh erwartet die Kopie unter ./wt, nur ABSOLUTE Pfade), bin/ (jobs_all.py, jobs/x.json, Auswertungen
  mesh_analysis.py, lamp_vis.py, lamp_occlusion.py, dup_check.py, flake_shimmer.py, sheet_*.py), Zahlen in out/*.txt.
- Fallstricke:
  - ModernMaterials.set_class_parameter wirkt nur auf vorhandene Materialien -> erst _mats.material("vpbr"/"glass"),
    dann LOOK setzen (derselbe Fehler steckt in tools/models/contact_sheet.gd von AS2a: --look=race == neutral).
  - erster Job eines Laufs war bei mir NICHT unruhig (gemessen gleich nach 60 Bildern); der Unterschied kam vom Look-Fehler.
  - Showroom von UI1 setzt den Look nicht.
