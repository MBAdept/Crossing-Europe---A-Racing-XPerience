# QA-R6 – Unabhängige Prüfung von R6 (Tankstelle, Grenze, Stadt, Start/Ziel, Blitzer)

- Prüfstand: `c8b18d1` (origin/wip/v080-r6), Basis `6e48405` (origin/wip/v080-m2int)
- Worktree: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-2` (ff auf `c8b18d1`, nichts
  committet); Basis-Kopie (git archive `6e48405`) und Mutations-Kopie (git archive `c8b18d1`) unter
  `…/scratchpad/v080/m1/QA-R6/{base,mut}` (nach den Läufen gelöscht)
- Kein Commit, kein Push, kein Branch. Alle schweren Läufe einzeln mit `nice -n 10` (`QA_M2_FERTIG` lag), eigenes absolutes
  `XDG_DATA_HOME` je Lauf, Mesa llvmpipe unter Xvfb, Last der Maschine 14–19 (gemessen mit `/proc/loadavg`).
- „gemessen“ = auf dieser VM gelaufen; „gefolgert“ = aus Code/Daten geschlossen. Über Steam Deck und echte GPUs ist nichts
  gemessen; die Deck-Bilder sind die Voreinstellung `deck` auf llvmpipe.

PLATZHALTER
