## 8. Dateien und Werkzeuge

Abgabeordner `<scratch>/v080/deliver/QA-BILD/`:
- `ab_mittel/` – A/B-Bögen aller Referenzpositionen S1–S5, T1–T4, C1, N1, N2, U1, DEV bei 2 s und 6 s, Voreinstellung Mittel
- `ab_varianten/` – S1 um 6 Uhr, 19:30, 22 Uhr; S2 um 22 Uhr; S1 mit Niedrig, Hoch und Steam Deck (1280 × 800)
- `details/` – vergrößerte Ausschnitte zu den Befunden (`crop_*.jpg`), Rückfallbild
- `clips/` – `s1_ab_arcade_modern_hoch.mp4`, `t4_ab_arcade_modern_mittel.mp4`, `n1_ab_arcade_modern_mittel.mp4`
  (nebeneinander, gleicher Simulationszustand), `s1_modern_hoch_60fps.mp4`
- `pruefungen/` – Protokolle: Fairness (`sight_full.log`, `path_full.log`), Leistungsfahrten (`kh_*`, `mem_*`),
  Golden, Render-Prüfungen, gespeicherte Prüfbilder

Werkzeuge (Arbeitsordner `<scratch>/v080/m1/QA-BILD/`, nicht im Repository):
- `tools/ab.sh <ordner> <voreinstellung> <Position …> [-- Argumente]` und `tools/abf.sh` – A/B wie `tools/ab_shot.sh`,
  Modern mit `--shot-fast` und 1 s Vorlauf (an S2 gegen den vollen Lauf geprüft); Positionen S1–S5, T1–T4, C1, N1,
  N2, U1, DEV und Varianten
- `tools/clip.sh`, `tools/abclip.py` – Movie-Maker-Clips mit 60 Bildern/s und A/B-Schnitt
- `tools/crop.py`, `tools/seq.py` – Ausschnitte und Bildfolgen aus Clips
- `probe/qa_drive.gd` + `tools/drive.sh` – ganze Etappe mit Bild-für-Bild-Zeiten, Speicherproben, `perf_stats`
- `probe/qa_spikes.gd` – Zeit jeder Ebene/jedes Builders (`update()`), Stellvertreter in `_updaters`
- `probe/drops.gd` – weggelassene Requisiten je Stück (`props.gd` → `debug()`)
- `tools/perfsum.py` – Auswertung der Fahrten

Vorsicht beim Nachstellen: `race_session.gd` setzt bei `--timescale` selbst `max_physics_steps_per_frame =
clamp(ceil(ts) × 2, 8, 128)` – ein eigenes `--max-steps` der Sonde wird überschrieben.
