# RINT-M3 STAND (16:02)

Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_a71eeb2e-3b7-1
Branch:   worktree-wf_a71eeb2e-3b7-1  (push target: origin wip/v080-rint-m3), head e240f1e
Base copy for comparisons: $S/base (git archive 32482114 + .godot, imported)
Helpers:  sh/env.sh rt.sh hs.sh rc.sh rcs.sh shot.sh pos.sh perf.sh occl.sh tri.sh queue_ab.sh queue_perf.sh

## Done (committed+pushed)
- merges 02457f1 a5f8b83 0dbb0b2, contract 79f5eca
- note 3 A-24 (+check_props_footprint gate, --full 0/218090, mutations 474/391)
- N-01 (release_chunk/release_under, glints skip), note 5 (ce_lod_band_m, mutations N1..N7 red), note 10 docs
- note 6 (landmarks place_model, 11.89 m test), note 8 (reflector abs+viewport_h, check_reflector_glint)
- note 7 (commit steps, split_arrays, PIECE_VERTICES 2000, warm part) 48147a2, N-02 cover quad e240f1e

## Running (detached, setsid)
- queue_perf.sh -> logs/queue_perf.log, perf/*.log (KH deck/medium head/base x3, pn head/base)
- queue_ab.sh -> logs/queue_ab.log, shots/ab/{hoch,deck,mittel}; waits for base VALS in logs/shots_n3.log
- background task: base T4..BEL + VALS head/base (shots/n02), log logs/shots_n3.log

## Next
- note 9: measure KHH22/LYON22 warm share -> likely AS5b
- note 7 collect(): read collect_by from perf logs; fix builder > 2 ms
- note 11: code analysis done (defaults = old path); optional sprite rerender
- clips; gates; bericht.md in deliver/RINT-M3

## Pitfalls
- Bash refuses chained git commands and complex heredocs: one git command per call; use Write tool for files
- do not edit loaded scripts while shots of the head tree run (queue_ab uses head)

## 23.11. 19:55 UTC – Leitung übernimmt selbst (Workflow-Werkzeug nach Abo-Ende nicht mehr verfügbar)
- Maschine neu gestartet: alle Hintergrundläufe weg. perf/ alt -> perf_old/; queue_perf.sh neu gestartet (Last ~2, allein)
- collect: kein Baustein > 2 ms (max bridge 0,44 unter Last 9–10); der collect-Höchstwert 7,4/9,9 ms kommt aus der
  synchronen Sichtkorridor-Rechnung (corridor.sync_ms_max 10,0) in capture() -> envelope_width() -> sight.ensure()
- danach: KHH22/LYON22 (Notiz 9), VALS head/base (N-02), A/B-Schlange, Clips, Gates, Bericht
- 20:25 chain1.sh (nach queue_perf: ×4-Läufe head/base, gates.sh …, occl head/base) und chain2.sh (nach ×4: sprite_check,
  VALS head/base, queue_ab, queue_clips) gestartet; Logs logs/chain1.log, chain2.log, gates/summary.txt

## 24.11. 00:25 UTC – Stand nach zwei Container-Neustarts (23:32, 00:19)
- Notizen 7, 9, 11, N-02 und Notiz 12 (Bilder angesehen) im Bericht; Tore bis Texturspeicher im Bericht (§4)
- Render-Prüfungen: 25 von 31 Dateien gelaufen; ROT: check_instance_budget_wald (ganze Szene 236 > 230, zweimal
  reproduziert; FIX-RINT 222, RINT-M2 216; Fahrzeugebene unverändert 208 -> der Rest wuchs von ~16 auf ~28-32)
  -> Sonde probe/wald_hist_probe.gd (Aufschlüsselung nach Shader und Besitzer) läuft in slotA
- jetzt WIEDERAUFNEHMBAR: sh/slotA.sh (Waldsonde, restliche Render-Prüfungen, Verdeckung, modern-make) und
  sh/slotB.sh (A/B-Rest ab NUE, Clips) – nach einem Neustart einfach beide neu starten:
    nohup bash $S/sh/slotA.sh > $S/logs/slotA.log 2>&1 &  ;  nohup bash $S/sh/slotB.sh > $S/logs/slotB.log 2>&1 &
- A/B-Urteile bisher: ab_notes.md (S0–T4, C1, N1, N2, U1, DEV, MUC, BEL, HAN, LYON, KHH22, LYON22)

## 24.11. 00:55 UTC – Befund der Montage behoben: d6d55b4 (gepusht)
- instanzen_wald 236 > 230: Ursache die Leitplanken-Stücke von A-28 (je Stück ein vpbr-Knoten); Fix: Flächen eines
  Knotens; instanzen 141, _wald 222, _stadt 177; test_road_builder + Mutation rot
- Endstand jetzt d6d55b4: slotA neu (run_tests2, alle Render-Prüfungen frisch in gates/render_checks.log – alte Datei
  render_checks_e240f1e.log, Verdeckung, modern-make); danach: Goldens ansehen/vergleichen (Bilder der KEEP-Läufe),
  committen, dann moderncheck2, scripts2, builds, smoke
