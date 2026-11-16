## 6. Leistung (gemessen auf llvmpipe unter Last; echte Hardware und Steam Deck abgeleitet)

### 6.1 Ganze Etappe Kiel – Hamburg im Modus Modern (Gate)

`m1/FIX-R5/perf.sh new|base kh`: `tests/race/run_stage.gd`, Kiel – Hamburg ab km 0 bis zum Ziel (Köhlbrandbrücke,
Elbbrücken: Wasser, Ufer, Fernwasser, Pylone, Seile, Fachwerk – R5s Bauten), Autopilot mit Tankstopp, 12 Uhr,
Limousine, Seed 11, Zeitraffer 4, Stufe „Mittel“, Xvfb 1280 × 720 – R5s Lauf. Derselbe Aufruf im Worktree (FIX-R5
`80b8141`) und in der Basiskopie (`git archive 5558bdc` + Import), direkt nacheinander.

PERF_KH_TABELLE

PERF_KH_LESART

### 6.2 Gotthard (Tunnel, „deck“) – Nachprüfung QR5-09

PERF_U1_TABELLE2
