# Wiederaufnahme (zuletzt aktualisiert 24.11.2026 ~03:45 UTC)

Haltung des Nutzers: Qualität vor Tempo, keine Prüfungen/Nacharbeit streichen; Lackflackern pausiert (A-21);
„bitte ohne meine Testergebnisse erst einmal weitermachen“. Nutzer schreibt Deutsch; Tags/Releases macht der Nutzer.

## Wo alles liegt
- Dieses Archiv: Branch origin/wip/v080-lead-archiv (Waisen-Branch, nur Text). Ordner v080/ = Scratchpad
  /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080
  (Berichte deliver/<PAKET>/bericht.md, Arbeitsstände m1/<PAKET>/STAND.md, Leitung m1/lead/), _journals/<lauf>/journal.jsonl
  = Ergebnisse jedes Agenten. Bilder/Clips/Builds sind NICHT im Archiv (nur im Container).
- Ist der Container weg: Archiv auschecken und nach demselben Scratchpad-Pfad kopieren (git worktree add … origin/wip/v080-lead-archiv,
  dann cp -a v080 <SCRATCHPAD>/), damit die Pfade in Skripten und STAND-Dateien wieder stimmen.
- Code: alles auf origin/wip/v080-* (Agenten pushen nach jedem Commit). Hauptcheckout bleibt v0.8.0 @ 92ece73.

## Stand der Linie (Köpfe auf origin) – aktualisiert 24.11. ~03:45 UTC
- FERTIG + geprüft: rint-m2 9b02f05, fix-rint 3248211, fix-r7a 4a43944, fix-r7b c50d58f, fix-r7c 3b3107b,
  **rint-m3 720eaf4** (Bericht deliver/RINT-M3/bericht.md; Arbeitsstand m1/RINT-M3/STAND.md).
- Das Workflow-Werkzeug steht seit 23.11. abends nicht mehr zur Verfügung: die Leitung arbeitet selbst, nacheinander,
  mit denselben Prüfungen. Lange Läufe als wiederaufnehmbare Skripte (Muster m1/RINT-M3/sh/slotA.sh, slotB.sh, slotC.sh:
  jeder Schritt prüft, ob sein Ergebnis schon da ist) – der Container wurde am 23./24.11. zweimal neu gestartet.

## Fortsetzen
1. R7d „Freie Strecke“ (A-27): Worktree .claude/worktrees/wf_a71eeb2e-3b7-1, neuer Branch wip/v080-r7d von 720eaf4;
   Brief = R7D_WHY/R7D_SCOPE/R7D_RULES/R7D_GATES in m1/lead/m6_r7d_draft.js. Danach eigene Kritik- und QA-Runde,
   FIX, Nachprüfung (früher KRITIK-R7D ∥ QA-R7D → FIX-R7D → NACH-R7D).
2. Danach: QA-mid (ganzes Rennen Kiel – Nürnberg in jeder Bedingung) → FIX/NACH → ZS2 (Goldens nach Ansehen,
   was_neu.md + Checkliste, Linux/Windows-Build, an den Nutzer per Datei).
3. Leitungsnotizen: m1/lead/m2_integration_notes.md (letzte Abschnitte zuerst).

## Maschinenregeln
- Schwere Jobs nice 10 (QA_M2_FERTIG gesetzt), Speicherwächter < 3 GB frei → warten, höchstens 2 Agenten je Workflow
  (Maschine mit 2 Agenten schon bei Last 8–10 auf 4 Kernen).
- Fertige Worktrees nach Push-Prüfung entfernen (Platz, ~9 GB frei); git worktree remove -f -f + Branch löschen.
  Worktree wf_db8ba6cd-508-6 behalten (41 MB _cache3d für die Modell-Nacharbeit).
- Godot-Läufe immer mit absolutem XDG_DATA_HOME (Benutzerordner am 22.11. bereinigt).
