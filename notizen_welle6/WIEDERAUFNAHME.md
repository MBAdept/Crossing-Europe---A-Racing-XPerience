# Wiederaufnahme (zuletzt aktualisiert 24.11.2026 ~18:15 UTC)

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
1. **R7d „Freie Strecke“ FERTIG** – Endstand **6092197** auf origin/wip/v080-r7d (Worktree
   .claude/worktrees/wf_a71eeb2e-3b7-1). Bericht deliver/R7D/bericht.md (Kurzfassung, Kritik K-1…K-8, Tore, Leistung,
   offene Punkte). Alle Tore auf 6092197 grün: run_tests 851/0, Bildprüfungen 32/0, golden 20/20 + 17/17, modern-check
   0/6 (erwartet, Bogen shots/goldens_modern_r7d.jpg), Verdeckung 144/147 gleich (Rest Pixelfarbe), sight 6/0, path 2/0,
   ERGEBNIS 3× identisch, Leistung gates/perf3_median.md (Pixelarbeit llvmpipe +17–24 %, sonst gleich). Bilder:
   shots/ab (A/B), shots/basis_kopf (alt|neu), clips/ (Tag, Dämmerung).
   Offene Punkte für QA-mid: Nacht (K-8), Regen-/Schneenacht 1,19×/1,22× (K-3), Schneefelder (K-7), Deck messen.
2. **QA-mid FERTIG, ZS2 GEBAUT UND AUSGELIEFERT** (25.11. ~05:30). Bericht deliver/QA-MID/bericht.md (§1–§10).
   FIX-Zweig wip-v080-qamid-fix → origin wip/v080-qamid-fix, Kopf **c5533a3** (= 072f9ec Korrekturen Q-01/Q-02/Q-04 +
   Golden-Liste modern_slice neu nach Ansehen). Tore: run_tests 855/0, Render-Prüfungen 32/32 (072f9ec), golden check
   Arcade 20/20 + 17/17 (c5533a3). Clips auf 6092197 + Tunnel/Schnee neu auf dem FIX-Kopf; Urteile ab/urteile.txt.
   Testbuild 2: build/testbuild/ZS2 im FIX-Baum, Lieferordner deliver/ZS2 (Archive als Hardlinks, SHA256SUMS,
   BUILDINFO, LIZENZEN, was_neu.md, steamdeck_checkliste.md); Rauchtests Linux/GLES/Windows-Wine OK (m1/QA-MID/zs2/).
   **Wartet auf die Rückmeldung des Nutzers zu ZS2** (Leistungstest-Dateien Deck/Windows, Antworten C.1–C.9).
   Die Integration nimmt wip/v080-qamid-fix statt wip/v080-r7d (enthält ihn ganz).
3. **WELLE 6 LÄUFT (Leitung selbst, kein Workflow-Werkzeug)** seit 25.11. abends: Zweig wip-v080-welle6 im Arbeitsbaum
   .claude/worktrees/qamid-fix (Basis c5533a3) → origin wip/v080-welle6. Plan (Arbeitsordner m1/W6, Bericht deliver/W6):
   AS5b Stadtgebäude Teil 2 – C1: eastern_plattenbau (7 Stile!), vienna_zinshaus/palais/kirche, spanish_casa/block/
   ladrillo, italian_block/palazzo/venezia; C2: central_barock/eckturm/jugendstil, eastern_house_a/b/c (house_c Garten
   23.000 Dreiecke trimmen), balkan_church/house/house_b/plattenbau, baltic_jugendstil/wood/wood_b.
   AS6 Wahrzeichen – L1: michel (neu), elbphilharmonie, neues_rathaus_hannover (prozedural), kaiserburg_nuernberg (4 Städte),
   dom_fulda, frankfurt_skyline, koelner_dom, fernsehturm_berlin, frauenkirche_dresden, frauenkirche_muenchen, st_petri_riga
   (auch Rostock); L2: stephansdom, riesenrad, mariendom_linz, dom_passau, dom_regensburg, veitsdom_prag, eiffel_tower,
   atomium, basilika_koekelberg, beffroi_calais, duomo_milano (+ voelkerschlachtdenkmal, florianturm, phare_calais);
   L3: campanile_venezia, sagrada_familia, basilica_pilar, kathedrale_burgos, parlament_budapest, kulturpalast_warschau,
   freiheitsdenkmal_riga, nevsky_kathedrale, stadtpfarrkirche_sibiu, catedrala_timisoara, catedrala_mantuirii,
   palatul_parlamentului (+ cuatro_torres, hram_svetog_save). Archiv frei (ZS2 gemessen): Netze 20,5/40, Texturen 24,3/60 MB.
   STAND 25.11. ~17:40: C1 alle 10 exportiert + angesehen (gut; spanish_casa Runde 2 dunkle Lückenfarbe), Notizen
   m1/W6/runden.md. LÄUFT (setsid nohup, wiederaufnehmbar): m1/W6/queue_c2.sh (C2 + Runde 2, Export→Commit→Ansicht,
   logs/queue_c2.log), m1/W6/ab.sh ab_c1.txt (Rennbilder A/B → m1/W6/ab/, logs/ab_c1.log), danach m1/W6/queue_l1.sh
   (Wahrzeichen L1, Slot der A/B, logs/queue_l1.log). Runde-2-Liste m1/W6/r2_list.txt (central_jugendstil).
   Lückenfarbe-Regel: dichtes Gitter vor dunklem Fenster dunkel, offenes Gitter/Baluster vor heller Wand Wandfarbe.
   STAND 18:10: C2 bis balkan_plattenbau exportiert+angesehen (gut), A/B ab_c1 6/12 angesehen (Beobachtung B-N1:
   Nachtfassaden 1,5–1,7 × Arcade, Lichtgesetz – Frage an Nutzer). NEU: m1/W6/queue_ab2.sh (A/B der C2-Städte
   ab_c2.txt, startet nach "QUEUE C2 DONE"); Zählung der 23 Sets m1/W6/census_as5b.txt (aus AS5a1/census_all.log).
   Am Ende: --manifest-only einmal allein laufen lassen (zwei Warteschlangen schreiben das Manifest parallel).
   >>> SICHERUNGSSTAND 26.11. 06:45 (Nutzer: Wochenlimit bald erreicht) <<<
   Git: wip-v080-welle6 = origin/wip/v080-welle6 = 9f82041, Arbeitsbaum sauber. Alles gepusht.
   FERTIG + angesehen: AS5b alle 23 Stadthäuser (C1+C2, Runde 2 jugendstil/barock/house_c; house_c validate OK),
   AS6 L1 9/9 (gut), L2 stephansdom + riesenrad (gut, N2 Speichenflimmern prüfen). A/B: ab_c1 12/12, ab_c2 4/10.
   docs/modelle.md §23 (AS5b) geschrieben. Notizen: m1/W6/runden.md (Kopie deliver/W6/runden_stand.md).
   LÄUFT selbstständig weiter (committen+pushen selbst): queue_l2.sh (L2/L3-Exporte), chain_ab.sh (ab_c2),
   queue_ablm.sh (ab_lm1 danach), queue_ablm23.sh (ab_lm2/3 danach). Nach Neustart diese vier neu starten.
   OFFEN (#126/#127/#128): Ansichten L2/L3 prüfen (shots/l2_*), A/B ab_c2-Rest + ab_lm1/2/3 ansehen; dann Tore:
   export_models --manifest-only allein, validate_models --report, check_sprite_geometry --only props --jobs 1,
   tools/run_tests.sh, tools/run_render_checks.sh (nacht_hell/anstrahlung/flugfeuer mit Modellen!), golden.sh check
   + modern-check (Kiel–Hamburg: Elbphilharmonie jetzt Modell → modern-make nach Ansehen), Build + pck_report;
   docs/modelle.md §24 (AS6) schreiben; Bericht deliver/W6/bericht.md mit Frage B-N1 (Nachtfassaden 1,5–1,7 ×
   Arcade: so lassen?) an den Nutzer; smooth=("cba_sign",) im Katalog ist wirkungslos (entfernen oder lassen).
   STAND 26.11. 05:41 (nach Container-Neustart): C2 + Runde 2 FERTIG und angesehen (alle gut; barock r2 byte-gleich).
   LÄUFT: m1/W6/chain_ab.sh (Rest ab_c1, dann ab_c2; AB_TIMEOUT 1200 in ab.sh) und m1/W6/queue_l1.sh (wartet nicht
   mehr auf AB DONE) – zwei schwere Jobs. queue_c2/queue_ab2 erledigt.
   Dazu m1/W6/queue_l2.sh (Wahrzeichen L2+L3, 23 Stück, startet nach "QUEUE L1 DONE"; Katalog db73d51).
   Dazu m1/W6/queue_ablm.sh (A/B der L1-Wahrzeichen ab_lm1.txt nach ab_c2 und L1).
   Dazu m1/W6/queue_r3.sh (eastern_house_c Runde 2 nach L1; queue_l2 wartet jetzt auf "QUEUE R3 DONE").
   Dazu m1/W6/queue_ablm23.sh (A/B L2+L3, ab_lm2.txt/ab_lm3.txt, nach ab_lm1 und L2 DONE). L1 und R3 FERTIG.
   Nach Neustart: chain_ab.sh, queue_l2.sh, queue_ablm.sh und queue_ablm23.sh neu starten (setsid nohup bash …); sie überspringen Fertiges.
   Rückstau Modellarbeit (A-29) danach: Sportwagen-Bremsband/Mittelbremslicht, GT-Silber nachts, Limousine Dämmerung,
   Tankstellen-Shop Nachtatlas, AS1b-Scheiben, Garten-Anbauten, Eckhaus-Rückseite K8, Wandleuchten K9, Bürohaus 15,9 px/m,
   Hansehaus 0,46× / Lyon 0,92/0,72× (Notiz 9).
4. Danach: Rückmeldung zu ZS2 auswerten (Deck-Leistung → Voreinstellung „Steam Deck“; Regen-/Schneenacht K-3;
   Kurvenkamera), dann Abschnitte 6–8 (Task #39): weitere Stadtstile (AS5b), Lack/Auto im Tunnel (A-29/AS5b),
   Schneefelder K-7; Lackflackern #76 bleibt pausiert bis der Nutzer es freigibt.
3. Leitungsnotizen: m1/lead/m2_integration_notes.md (letzte Abschnitte zuerst).

## Maschinenregeln
- Schwere Jobs nice 10 (QA_M2_FERTIG gesetzt), Speicherwächter < 3 GB frei → warten, höchstens 2 Agenten je Workflow
  (Maschine mit 2 Agenten schon bei Last 8–10 auf 4 Kernen).
- Fertige Worktrees nach Push-Prüfung entfernen (Platz, ~9 GB frei); git worktree remove -f -f + Branch löschen.
  Worktree wf_db8ba6cd-508-6 behalten (41 MB _cache3d für die Modell-Nacharbeit).
- Godot-Läufe immer mit absolutem XDG_DATA_HOME (Benutzerordner am 22.11. bereinigt).
