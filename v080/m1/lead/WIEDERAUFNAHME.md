# Wiederaufnahme nach dem Wochenlimit (gesichert 16.11.2026, Reset laut Nutzer Sonntag 22.11.)

Nutzer: „wir scheinen wieder ins Wochenlimit zu rennen (Reset erst wieder Sonntag). Bin bei 92%.“
Haltung des Nutzers: Qualität vor Tempo, keine Prüfungen/Nacharbeit streichen; Lackflackern pausiert (A-21).

## Wo alles liegt
- Dieses Archiv: Branch origin/wip/v080-lead-archiv (Waisen-Branch, nur Text). Ordner v080/ = Scratchpad
  /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080
  (Berichte deliver/<PAKET>/bericht.md, Arbeitsstände m1/<PAKET>/STAND.md, Leitung m1/lead/), _journals/<lauf>/journal.jsonl
  = Ergebnisse jedes Agenten. Bilder/Clips/Builds sind NICHT im Archiv (nur im Container).
- Ist der Container weg: Archiv auschecken und nach demselben Scratchpad-Pfad kopieren (git worktree add … origin/wip/v080-lead-archiv,
  dann cp -a v080 <SCRATCHPAD>/), damit die Pfade in Skripten und STAND-Dateien wieder stimmen.
- Code: alles auf origin/wip/v080-* (Agenten pushen nach jedem Commit). Hauptcheckout bleibt v0.8.0 @ 92ece73.

## Stand der Linie (Köpfe auf origin)
- fix-m2 515dd51 (Basis), fix-r4 b156763, fix-r5 80b8141, fix-r6 2b7dcc0, as5ar1 7153381 – alle geprüft + nachgeprüft.
- as5a2 (läuft/lief: AS5a Charge 2 dutch/belgian/french/paris/swiss), danach KRITIK-5a2 → AS5aR2.
- rint-m2 (läuft/lief: Zusammenbau der obigen), danach QA-RINT-BILD ∥ QA-RINT-SYSTEM → FIX-RINT → NACH-RINT.

## Fortsetzen
1. Workflows mit identischem Skript + Args + resumeFromRunId neu starten (fertige Agenten kommen aus dem Cache, abgebrochene
   laufen über das Restart-Protokoll weiter: STAND.md + wip-Branch):
   - RINT-M2: scriptPath m1/lead/wf_m4_rint.js, resumeFromRunId 'wf_9927a373-337', args = m1/lead/args_m4.json
   - AS5a:    scriptPath m1/lead/wf_m3b_stadt1.js, resumeFromRunId 'wf_db8ba6cd-508', args = m1/lead/args_m3b.json
     (nur Charge 2: {base, only:['2'], base2:'7153381…'} – siehe m2_integration_notes.md)
   Geht ein Resume nicht (Journal weg, neuer Container): denselben Workflow ohne resumeFromRunId starten – die Agenten finden
   ihre Vorgänger über m1/<PAKET>/STAND.md und origin/wip/v080-<paket> und machen dort weiter.
2. Danach laut Plan (A-21): R7 (A-17 Korridor-Hülle, Wahrzeichen/Skyline/Fern-LOD, Gebäude-Überblendung + max_dist_m,
   AS5a2-Merge, N1/N2/N3, B2, Fernstreifen) → QA-mid (ganzes Rennen Kiel – Nürnberg in jeder Bedingung) → ZS2
   (was_neu.md + Checkliste, Linux/Windows-Build, an den Nutzer per Datei).
3. Leitungsnotizen: m1/lead/m2_integration_notes.md (chronologisch, letzte Abschnitte zuerst lesen); Vertrag §11.3:
   m1/lead/contract_11_3.md (RINT-M2 committet ihn in docs/dev/v080_contract.md).

## Maschinenregeln
- Schwere Jobs nice 10 (QA_M2_FERTIG gesetzt), Speicherwächter < 3 GB frei → warten, höchstens 2 Agenten je Workflow.
- Fertige Worktrees nach Push-Prüfung entfernen (Platz); git worktree remove -f -f + Branch löschen.
