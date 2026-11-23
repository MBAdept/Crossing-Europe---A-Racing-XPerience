# Wiederaufnahme (gesichert 22.11.2026 ~22:30 UTC – Nutzer: „in 30 Minuten läuft mein ULTRA-Abo ab“)

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

## Stand der Linie (Köpfe auf origin) – aktualisiert 23.11. ~14:50 UTC
- FERTIG + geprüft: rint-m2 9b02f05, fix-rint 3248211, fix-r7a 4a43944, fix-r7b c50d58f, fix-r7c 3b3107b.
- LÄUFT: Workflow wf_m6.js (Lauf wf_a71eeb2e-3b7, args m1/lead/args_m6.json): RINT-M3 (Zusammenbau, Vertrag §11.4 aus
  m1/lead/contract_11_4.md) → R7D „Freie Strecke“ → KRITIK-R7D ∥ QA-R7D → FIX-R7D → NACH-R7D.
  Branches wip/v080-rint-m3, wip/v080-r7d, wip/v080-fix-r7d.

## Fortsetzen
1. Workflow({scriptPath: '<SP>/m1/lead/wf_m6.js', resumeFromRunId: 'wf_a71eeb2e-3b7', args: <Inhalt von args_m6.json>})
   (fertige Agenten aus dem Cache; abgebrochene über STAND.md + wip-Branch). Ohne Journal: ohne resumeFromRunId starten.
2. Danach: QA-mid (ganzes Rennen Kiel – Nürnberg in jeder Bedingung, zwei Linsen) → FIX/NACH → ZS2 (Goldens nach Ansehen,
   was_neu.md + Checkliste, Linux/Windows-Build, an den Nutzer per Datei).
3. Leitungsnotizen: m1/lead/m2_integration_notes.md (letzte Abschnitte zuerst); Ergebnisse: m1/lead/rint_res/, m1/lead/r7_res/.
4. Skript-Bausteine: <x>_meta.js + c1_head.js + <x>_body.js, Trockenlauf dryrun7.mjs (Ausgaben in eigenen Ordner kopieren).

## Maschinenregeln
- Schwere Jobs nice 10 (QA_M2_FERTIG gesetzt), Speicherwächter < 3 GB frei → warten, höchstens 2 Agenten je Workflow
  (Maschine mit 2 Agenten schon bei Last 8–10 auf 4 Kernen).
- Fertige Worktrees nach Push-Prüfung entfernen (Platz, ~9 GB frei); git worktree remove -f -f + Branch löschen.
  Worktree wf_db8ba6cd-508-6 behalten (41 MB _cache3d für die Modell-Nacharbeit).
- Godot-Läufe immer mit absolutem XDG_DATA_HOME (Benutzerordner am 22.11. bereinigt).
