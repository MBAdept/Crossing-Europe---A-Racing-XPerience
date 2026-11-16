## 8. Werkzeuge und Rohdaten

Arbeitsordner `/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/KRITIK-R2-MESS/`
(Kopien der Stände und Aufnahmen nach dem Bericht gelöscht; Ergebnisse und Skripte bleiben):

- `tools/` – Kopien der Skripte der Nachmessung (KRITIK-R) in der Fassung von AU-R2 (`ktools/`): `kr_crash.gd`,
  `kr_perf_conc.gd`, `kr_seam.gd`, `kr_worst.gd`, `vol_probe.gd`, `dsp.py`, `ana_cap.py`, `ana_compare.py`,
  `ana_crash.py`, `crash_p95.py`, `ana_peaks.py`, `ana_mod.py`, `char_cmp.py`; `perf_asph.gd` (= `perf_auc1.gd` von
  KRITIK-FAHRBAHN, Asphalt km 76), `drive_ab.gd` (AU-R2 `prev/`, die Fahrt der Hörproben).
  Eigene: `km_capture.gd` (= `kr_capture.gd` + `--seed` + Sperrzähler zu Beginn jedes Abschnitts), `km_slab.gd`
  (= `kr_slab.gd` + `--align-ms` + Zähler je Bild), `kr_restart.gd` (Verhalten von Godot bei Start, Neustart,
  Pegelschritten, Stopp), Pläne `plan_m{B,S,S2,A,V,C,Bx}.json`, `ana_slabsweep.py`, `ana_slabcurve.py`,
  `ana_slabclick.py`, `ana_restart.py`, `ana_seam2.py` (WAV-Schleifen mit Schleifenende), `ana_cobblepeaks.py`,
  `ana_perf.py`, `ana_prev.py`, `ana_marks.py`, `ana_ident.py`, `ana_drivecmp.py`, `plot_levels.py` (nur zur eigenen
  Sichtkontrolle), Abläufe `run_cap.sh`, `batch1.sh`–`batch3.sh`, `mk_head.sh`.
- `res/` – alle Ergebnisse als JSON, `logs/` – alle Protokolle (je Lauf eins), `fig/` – Pegelverläufe der Hörproben
  (eigene Kontrolle, nicht für den Nutzer).
