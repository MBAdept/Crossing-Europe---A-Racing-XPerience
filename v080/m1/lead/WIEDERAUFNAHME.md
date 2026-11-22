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

## Stand der Linie (Köpfe auf origin)
- FERTIG + geprüft: rint-m2 9b02f05 (2. Montage), fix-rint 3248211 (nach QA-RINT-BILD/-SYSTEM; NACH-RINT: tragfähig,
  aber N-01 Reflektoren-SCRIPT-ERROR zuerst beheben → RINT-M3), as5ar2 216ac5c (in R7c gemergt).
- LÄUFT beim Abbruch: R7-Workflow (wf_ba4424b4-294, Skript m1/lead/wf_m5_r7.js, args m1/lead/args_m5.json):
  R7a gebaut 509bb16 (origin/wip/v080-r7a), QA-R7a läuft; R7b gebaut 2c154bc (origin/wip/v080-r7b), QA-R7b fertig
  (Ergebnis im Journal); R7c baut noch (origin/wip/v080-r7c 8153d20 – letzter Commit = fehlende .uid von check_lod_band, von der Leitung; ungesicherte Hilfsdateien zusätzlich auf
  origin/wip/v080-r7c-sicherung 8b33b62 – nur tools/r7c_tmp und eine .uid, nicht mergen).

## Fortsetzen
1. R7-Workflow mit identischem Skript + Args + resumeFromRunId neu starten:
   Workflow({scriptPath: '<SP>/m1/lead/wf_m5_r7.js', resumeFromRunId: 'wf_ba4424b4-294', args: <Inhalt von args_m5.json>})
   (fertige Agenten kommen aus dem Cache; abgebrochene laufen über STAND.md + wip-Branch weiter).
   Geht Resume nicht (Journal weg): ohne resumeFromRunId starten – Agenten finden Vorgänger über STAND.md/origin.
2. Danach (Leitungsentscheid 22.11., Details m2_integration_notes.md letzter Abschnitt):
   a) RINT-M3: fix-rint 3248211 + R7a/R7b/R7c (FIX-Köpfe) mergen. Probe-Merge: Konflikte nur chunk_streamer.gd
      (fix-rint × r7a), docs/renderer-modern.md (r7b), tests/unit/race3d/test_props.gd (r7c). Notizen: N-01
      (is_instance_valid in lights._update_glints + Unit-Test), N-02 (Ausfahrt-Quad letzte 2 m), Einhängen innerhalb
      roadside/terrain/road teilen (≤ 3 ms/Bild, sonst messen+listen), Regel 8 (XDG_DATA_HOME in allen Sonden),
      Sprites bytegleich (R7c ändert cesprites/props_cities.py mit 3D-Haken), F-04 Hansehaus nachts nachmessen,
      F-07 Hochhaus Frankfurt, Modern-Goldens einmal nach Ansehen, Vertrag §11.4 (R7-Aufteilung, 3 Oberflächen/attach,
      Einhänge-Budget, R7d, Plan).
   b) R7d „Freie Strecke“ (QA-RINT-BILD F-02 hoch: offene Autobahn ≈ Arcade) auf RINT-M3: Wolkenhimmel (aus R8
      vorgezogen), Wolkenschatten, Fahrbahnverschleiß, Wiesen/Felder, Relief außerhalb A-17-Hülle, Baumschatten,
      Luftperspektive nur innerhalb F4. Entwurf des Auftrags: m1/lead/m6_r7d_draft.js. Dann QA → FIX → NACH.
   c) QA-mid (ganzes Rennen Kiel – Nürnberg in jeder Bedingung) → FIX/NACH → ZS2 (was_neu.md + Checkliste,
      Linux/Windows-Build, an den Nutzer per Datei).
3. Leitungsnotizen: m1/lead/m2_integration_notes.md (chronologisch, letzte Abschnitte zuerst lesen); Ergebnisse
   der RINT-Prüfung: m1/lead/rint_res/r1..r5.json; Vertrag §11.3: m1/lead/contract_11_3.md (committet in 8999769).
4. Skript-Bausteine: <x>_meta.js + c1_head.js + <x>_body.js, Trockenlauf mit dryrun7.mjs. Vorlage für RINT-M3:
   m4_body.js (RINT-M2 → QA zwei Linsen → FIX → NACH).

## Maschinenregeln
- Schwere Jobs nice 10 (QA_M2_FERTIG gesetzt), Speicherwächter < 3 GB frei → warten, höchstens 2 Agenten je Workflow
  (Maschine mit 2 Agenten schon bei Last 8–10 auf 4 Kernen).
- Fertige Worktrees nach Push-Prüfung entfernen (Platz, ~9 GB frei); git worktree remove -f -f + Branch löschen.
  Worktree wf_db8ba6cd-508-6 behalten (41 MB _cache3d für die Modell-Nacharbeit).
- Godot-Läufe immer mit absolutem XDG_DATA_HOME (Benutzerordner am 22.11. bereinigt).
