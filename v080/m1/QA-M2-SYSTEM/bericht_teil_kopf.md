# QA-M2-SYSTEM – unabhängige Prüfung der ersten M2-Montage (Arcade-Identität, Klang, Modell-Pipeline, Robustheit)

- **Geprüfter Stand:** `6e484056ec87e2fa614061000a362feb2b5a6db8` (`origin/wip/v080-m2int` = `origin/wip/v080-m2zs1`, M2INT + ZS1-Merge),
  Prüf-Arbeitsbaum `.claude/worktrees/wf_438996b0-243-4` (fast-forward auf den Kopf, `.godot` kopiert und importiert,
  **keine Änderung, kein Commit**). Prüfkopien für Mutationen, Rückfall- und Export-Versuche: `m1/QA-M2-SYSTEM/mut`
  (`git archive` des Kopfes), v0.7.0-Referenz `git archive main` – beide, das Wine-Präfix und `build/` nach Gebrauch gelöscht; Skripte und
  Logs bleiben in `m1/QA-M2-SYSTEM/` (`bin/`, `gd/`, `q_*.log`, `mutations/`, `sound/`, `tyrewind/`).
- **Maschine:** 4 Kerne, llvmpipe (Software-OpenGL), Dummy-Audiotreiber, geteilt mit R4, R5, AS5a, QA-M2-BILD (Last
  meist 13–33). Alles über Steam Deck, echte GPU oder Hörempfinden ist **abgeleitet**; alle Zahlen unten sind
  **gemessen**, wo nicht anders gesagt.
- **Ablauf:** drei Durchgänge (Container-Neustarts am 13.11. 05:23 UTC während des Goldens und am 15.11. vor 08:03 UTC;
  die Nachfolger haben über `STAND.md` und die Logs übernommen). Der dritte Durchgang (15.11.) hat nachgeholt: die
  Waldprüfung bis zum Ergebnis, Wind/Reifen/Menüklänge einzeln, die Nachläufe der Mutationen, den Modern-Änderungsmelder
  und die Beenden-Fälle der laufenden Modern-Etappe.
- **Lesart:** „gemessen“ = an Datei/Log/Bild in diesem Lauf festgestellt; „abgeleitet“ = geschlossen, nicht gemessen;
  „gelesen“ = aus Berichten anderer Pakete übernommen und als solches gekennzeichnet.
