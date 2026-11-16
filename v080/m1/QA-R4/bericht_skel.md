# QA-R4 – Unabhängige Prüfung von R4 „Licht, Nacht, Wetter“

Prüfling: `origin/wip/v080-r4`, Kopf `7f0eae2` (20 Commits über der Basis `6e48405` = `origin/wip/v080-m2int`).
Prüfer-Worktree `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-3` (vorgespult auf
`7f0eae2`, **kein Commit, kein Push**); Basis als `git archive`-Kopie (importiert) unter `m1/QA-R4/base`; Mutationen in
einer Kopie des Kopfes (`m1/QA-R4/mut`). „gemessen“ = auf dieser VM (llvmpipe unter Xvfb bzw. headless, 4 geteilte
Kerne, Last 13–18 durch andere Pakete); alles über Steam Deck, echte Grafikkarten und Wirkung auf Menschen ist
**abgeleitet**. Alle Läufe mit absolutem `XDG_DATA_HOME` und `--graphics=` ausdrücklich, schwere Jobs nacheinander,
`nice -n 10` (`QA_M2_FERTIG` lag vor).

@@URTEIL@@

## Befunde

@@BEFUNDE@@

## Geprüft und in Ordnung

@@OK@@

## 1. Bilder (`tools/ab_shot.sh`, Modern „Hoch“ wenn nicht anders genannt; angesehen)

Jede Stelle als A/B gegen Arcade desselben Simulationszustands und gegen die Basis `6e48405` (Modern der Basis mit
denselben Argumenten). Dateien in `deliver/QA-R4/bilder/`.

@@BILDER@@

## 2. Funktion im ganzen Netz

@@FUNKTION@@

## 3. Fairness

@@FAIR@@

## 4. Arcade-Gleichheit und Dateibesitz

@@BESITZ@@

## 5. Tests, Render-Prüfungen und Mutationen

@@TESTS@@

## 6. Leistung

@@PERF@@

## 7. Vertragsfragen

@@VERTRAG@@

## 8. Für die nächsten Pakete

@@NEXT@@
