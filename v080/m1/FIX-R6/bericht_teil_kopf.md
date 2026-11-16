# Bericht FIX-R6 – Nacharbeit nach der Prüfung QA-R6 (Tankstelle, Grenze, Stadt, Start/Ziel, Blitzer)

- Worktree: `/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_3b3101bc-877-3`
- Branch: `worktree-wf_3b3101bc-877-3`, Sicherung `origin wip/v080-fix-r6` (nach jedem Commit gepusht, nie erzwungen)
- Basis: `c8b18d1` (Kopf von R6, `origin/wip/v080-r6`) per `git merge --ff-only`; kein Vorgänger dieses Laufs (weder
  `STAND.md` noch `wip/v080-fix-r6`)
- Code-Kopf `2c75af0`, Gate-Kopf HEADCOMMIT (dazu nur die Modern-Änderungsmelder)
- „gemessen“ = auf dieser VM gelaufen (headless bzw. Mesa llvmpipe unter Xvfb, `nice -n 10` – `QA_M2_FERTIG` lag –,
  eigenes absolutes `XDG_DATA_HOME` je Lauf, Last der Maschine 9–16); „gefolgert“ = aus Code, Daten oder Bildern
  geschlossen. Über echte Grafikkarten und das Steam Deck ist nichts gemessen; die Deck-Bilder sind die Voreinstellung
  `deck` auf llvmpipe.

## 0. Kurzfassung

**Alle Befunde von QA-R6 nachgestellt; B-01, B-02, B-04 behoben, B-03 an Start/Ziel und Grenze behoben, an der Tankstelle
bei Nacht nur teilweise (Modell-Frage), B-05–B-08 begründet nicht geändert bzw. gemessen.**

- **B-01 (mittel):** die 5 schwebenden Grenzdächer (QA hatte recht: 5, nicht 4) hängen jetzt an je zwei **Masten mit
  Zugstangen** über der Platte; nichts Neues in der Sichtschneise. QAs Ein-Zeilen-Vorschlag (äußerer Pfeiler in der
  Sichtschneise) habe ich gemessen und verworfen: er verdeckt an 3 der 5 Dächer 36–174 Sichtlinien zu Autos, die Arcades
  Pfeiler nicht verdeckt. Netzweit 0 schwebende Dächer.
- **B-02 (niedrig):** die Endstütze der Tankstellendächer wird gegen echte Sichtlinien (beide Seiten, 600 m, Kurven)
  geprüft: Verdeckungen ferner Tafeln netzweit **1109 → 38** Paare, mit Tafeln ≥ 6 px **195 → 5** (nur noch an 3
  Dächern, die sonst ohne Stütze wären). Hauptthread-Kosten verteilt (höchstens 1,1–6,7 ms je Stück, Basis 0,1–0,6 ms; gemessen unter Last).
- **B-03 (mittel, Look):** Start- und Zieltor mit weißen Stützen, **Fachwerkträger und drei Flutlichtern** (nachts
  Lichtkegel vor der Linie, Banner so rot wie Arcade) – bei Tag und vor allem bei Nacht **klar besser** als Arcade
  (vorher: kein Gewinn, nachts leicht schlechter). Grenzblende nachts heller. Tankstelle nachts: warmes Vorplatzlicht am
  Shop, aber weiter **nur gleichwertig** – Arcades leuchtende Gebäudefront braucht das Nachtbild des AS1b-Modells.
- **B-04:** die drei Test-Wächter prüfen gegen Arcades Literale; die Mutationen M03, M06, M08 sind jetzt rot.
- Gates siehe Abschnitt 2: Arcade bildgleich, Fairness-Gates grün, Render-Prüfungen RENDERSUMMARY, `run_tests.sh`
  TESTSUMMARY.
