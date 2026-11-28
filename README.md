# Wiederaufnahme (zuletzt aktualisiert 28.11.2026 ~07:25 UTC)

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
   Dazu m1/W6/gates.sh (Tore nach "QUEUE L2 DONE", je Schritt gates/<name>.done, Log logs/gates.log).
   Dazu m1/W6/queue_r4.sh (Eiffelturm neu mit drop_caps nach L2; gates.sh wartet auf "QUEUE R4 DONE").
   26.11. 12:05: ab_lm1/2/3 ersetzt durch m1/W6/queue_ablmp.sh (ab_lmp.txt: alle 33 vom Platz vor dem Anker, ab_lm.sh).
   12:10: R4 erledigt (Eiffel, Atomium); R5 = m1/W6/queue_r5.sh (Newski, Erlösung, Belfried, Campanile, Freiheitsdenkmal:
   Goldkuppeln vpbr, 1024er-Atlas als WebP – Texturquellen waren 60,04 > 60 MB); gates2.sh wartet auf "QUEUE R5 DONE".
   12:28: R5+R6 FERTIG (Gold vpbr + auto_lod aus bei Newski/Erlösung; WebP; Quellen 58,7 MB). R7 = m1/W6/queue_r7.sh
   (Splitter-Fix min_height in build_baked; Frankfurt + Belfried neu), Tore m1/W6/gates4.sh warten auf "QUEUE R7 DONE".
   A/B: queue_ablmp.sh mit Start 1,6 Etappen-km vor dem Anker (ab/alt_p = alte Läufe). Bögen: m1/W6/sheet_ab.py.
   N2 gemessen (runden.md): Riesenrad-Speichen flimmern ab ~250 m (Vorschlag: Renderer, eigener Schritt).
   Doku §24 Entwurf: m1/W6/doc24_head.md + doc24_body.md (Tabelle nach R7 mit table_as6.py).
   14:45: TORE FERTIG und grün nach Fixes: validate OK, spritegeo OK, render 30/30 (props_spiegel per Test-Manifest),
   golden Arcade OK, Modern-Golden s4 neu (angesehen, ece4bdd), unit landmarks 12/12 + props 28/28; ganze Suite läuft
   noch einmal (m1/W6/gates6.sh → gates/run_tests2.log). Fixes: capped_turn (84373e0), Tests/Test-Manifeste,
   Atomium A2 (0cde5d2). Doku §24 (917965d), Bericht deliver/W6/bericht.md (fast fertig: @UNIT@/@KOPF@ füllen).
   DANACH: N6 Blickwinkel (Task #129) – Exporter schreibt view_yaw_deg (c2f9b4a), Nachtrag m1/W6/patch_view_yaw.py
   (dann --manifest-only), Renderer landmarks.gd place_model + near_shift-Bezug + Grenze hinter clear_m[1]; Notizen
   runden.md „N6“. Danach N2 Speichen (#130).
   15:02: WELLE 6 ABGESCHLOSSEN. Ganze Suite auf 0cde5d2: 856 Tests / 0 fehlgeschlagen, alle CHECKS OK. Bericht
   deliver/W6/bericht.md fertig (Frage B-N1 an den Nutzer), runden_stand.md kopiert. Gepusht origin/wip/v080-welle6.
   15:48: N6 FERTIG (65c9999 Code, 2b93865 Golden, 2c0b1d0 Doku): Modelle im Sprite-Blickwinkel, Häuserzeile
   HOUSE_BAND_M 36 m; ganze Suite 857/0, Render Wahrzeichen OK, Golden Arcade gleich, Modern s4 erneuert;
   Vorher/Nachher ab/n6_cmp_*.jpg (Sibiu, Mailand, Dresden, Koekelberg, Atomium besser). Bericht W6 ergänzt.
   N2 (27.11. 16:15): Klasse "thin" (ce3d/thin.py, props3d Option thin, landmark.gdshader CE_THIN, landmarks.gd,
   ModernMaterials-Rückfall, bake ohne LOD, Prüfer), Riesenrad neu exportiert, commit e93a622 (gepusht).
   Messung prop_scene 250/600/1000 m: 2,0/0,2/0,1 % (vorher 6,5/8,8/4,5, Sprite 2,1/0,6/0,1). check_thin_render neu
   (OK). test_landmarks 14/14. A/B ab/n2_* angesehen: gut. Doku modelle.md §25, renderer-modern 19.1/19.2/19.6,
   bericht.md §1/§5 (noch nicht committet: Doku). Tore gates_n2.sh laufen (render_all, golden, run_tests).
   18:02 N2 FERTIG: Doku 0ca7799; Tore gates_n2: Render 31/31, Golden Arcade 20/20 + UI 17/17, Modern 6/6, GLES ok,
   Suite 858/0. Bericht §1/§5/§6 ergänzt.
   18:15 Deck-Messungen des Nutzers ausgewertet (lead/perf_deck/*.json; ACHTUNG: Deck lief Testbuild 1 = 0.8.0-zs1):
   deck 111-120 fps, high 106-113 fps, Reserve 1,87/1,77, high nur +6 % -> CPU-begrenzt. Heutiger Stand hier gemessen
   (here_deck/high.json): Stadt 256 statt 187 Draw-Calls, 189k statt 34k Dreiecke. Doku docs/steam-deck.md (de6f377).
   Preset bleibt bis PERF; Nutzer um Neumessung mit ZS2 (beide Presets, evtl. angedockt) gebeten.
   19:35 Nutzer schickte ZS2-Deck-Messungen (lead/perf_deck/zs2_deck.json, zs2_high.json): deck 108-119, high
   103-115 fps. A-30: deck = {2,2,100,2,2} (config, Gfx.DEFAULT_PRESETS, Quality.STEPS deck->medium, Tests,
   Vertrag §11.5 A-30/A-31, steam-deck.md, grafik-modi.md). Bericht W6 §1/§8. Tore gates_deck: Suite 858/0,
   Render instance_budget 3/3. Commit ed84daa (gepusht).
   A-29 (19:20-20:00): Verkehrs-Sportwagen Bremslicht 54535c4 (gepusht); Lack GT/Sport/Limo, Tankstellen-Fenster,
   Flimmern Kontor/Gracht/Chalet nachgemessen -> kein Eingriff; Stand in Bericht W6 §9. Offen: K8 Eckhaus-Rückseite,
   Nachtfenster Hansehaus (mit B-N1 zusammen, Nutzerantwort abwarten).
   20:05 NUTZER B-N1: Nachtansicht "lebendig" lassen. -> F-04: AS5a-Nachtfenster (Hanse 0,46x, Lyon) auf >= Arcade
   heben (Ziel warm share 0,85-1,15x, eher oben). F-04 nachgestellt (W6/f04/, warm_ab.py ohne HUD-Pixel):
   AS5a-Städte Arcade-Verhältnis pa 1,11/0,46 am 1,23/0,82 br 1,06/0,68 ly 0,57/0,77 be 0,65/0,70 hh 0,73/0,90
   (Median ~0,72); AS5b (W6 ab/*_nacht) wien 0,71 wars 1,59/0,87 prag 1,12/0,90 mail 1,10/1,08 sofia 0,96/0,83
   (Median ~0,95); Hanse-Haus rechts 0,46. Plan: cities3d _log_walls-Wrapper mit lit_k (nur 3D, r1<lit*k = Obermenge
   der Sprite-Fenster), AS5a lit_k ~1,35, neu exportieren, nachmessen. (Task #136)
   20:40 NUTZER NEU (Vorrang): HUD oben Streckenübersicht entfernen, nur Distanz zum Ziel; Radar-Warnungen erst
   zufällig 5-10 km vor dem Auslöser einblenden. -> zuerst das, dann F-04.
   20:50 HUD/Radar umgesetzt (Task #137, noch NICHT committet, Arbeitsstand auf 54535c4): hud.gd (_draw_goal_distance,
   GOAL_Y 102, Strafe darunter, --hud-demo=penalty), stage_plan.gd radar_warn_distance (warning_km [5,10], rng seed+202,
   ganze km, ein Zug je Dateneintrag), race_session Meldung = Abstand dieses Radars, fixtures warn, 2 neue Tests in
   test_network_data (281 Radare, 41-53 je km 5..10), Doku (ui, gameplay, README, Design, renn-modul, steam-deck,
   staedte, ARCHITECTURE, qa-v080, golden README, Vertrag A-32 + Regel 2/D38/4.9.3). Arcade-Referenz NEU:
   tests/golden/arcade_ref.patch (v0.7.0 + Nutzerwunsch, git apply in golden.sh make, env patch=MD5, check bricht bei
   anderem Patch ab). Tore: W6/gates_hud.sh (make KEEP gates_hud/arcade_ref, check, modern-check KEEP, Suite, render
   all) – nach Neustart einfach neu starten (überspringt Fertiges; make.done löschen, falls make abgebrochen).
   Danach: alte/neue Arcade-Hashes vergleichen (gates_hud/old_*.md5), geänderte Bilder ANSEHEN, Modern-Bilder ansehen
   -> modern-make, Bericht W6 §10, Commit + Push, dann F-04 (#136).
   21:45 Stand: A-32 committet+gepusht 2977f70 (Code), 8f6c0d1 (Arcade-Listen, check 20/20 + 17/17, alle 23 Bilder
   angesehen), 8e9a3ea (Modern-Liste aus modern_keep; S2 = Radarschild, Nacht = A-29-Rücklicht). Suite 0 Fehler.
   Laufend: gates_hud.sh render_all, danach gates_hud2.sh (modern-check zur Bestätigung). Bericht §10 hat noch
   TORE_HUD_PLATZHALTER -> nach render_all/modern2 füllen, Bericht kopieren, Task #137 schließen.
   F-04 (#136) begonnen, NICHT committet: cities3d._log_walls(lit_k, LIT_MAX 0.85; Aufruf orig(*ba.args, **ba.kwargs)),
   catalog3d AS5A_LIT_K 1.35 für 23 AS5a-IDs. Neutralität belegt (city_balkan_house neu exportiert: bis auf den
   Schlüssel byte-gleich). f04/export.sh (Blender, nur _cache3d) läuft; f04/after.sh wartet auf HUD2 + Export, backt,
   importiert, Manifest, validate, A/B nach f04/after/, warm.txt. Danach: Bilder ansehen, ggf. lit_k je Stadt
   anpassen, Tore (Suite, render modern, golden check/modern-check), Doku modelle.md + Bericht, Commit.
   Platz: R7D/QA-MID-Caches und Worktree wf_a71eeb2e (r7d, gemergt) entfernt -> ~6 GB frei.
   23:15 A-32 FERTIG (Task #137): render all 33/33, modern-check nach Neuaufnahme 6/6; Bericht W6 §10 Tabelle gefüllt.
   F-04: 23 Exporte rc 0 (Dreiecke wie Manifest, nur Licht), Bake/Import/Manifest/validate OK (23:12). after.sh macht
   A/B nach f04/after/ + warm.txt (Ende "F04 AFTER DONE" in logs/f04.log). Danach ansehen, ggf. lit_k je Stadt, Tore.
   Archiv: archiv.sh + archiv_push.sh (push jetzt aus qamid-fix, --git-dir; alter wf_a71eeb2e-Baum ist weg).
   23:55 F-04: Modelle 5aa984c (21/23 emit geändert; office/french_sud gleich), Doku+Vertrag A-33 9cc4d2c (gepusht).
   Messung f04/after/warm_final.txt: Median streng 0,75->0,80, weit 0,79->0,90 (AS5b 0,96/0,87), khh Hansehaus
   0,47->1,41. lit_k 1,35 bleibt. Vergleichsbilder f04/cmp_*.jpg (khh neu bei km 88,2; S4-Fehlschuss in after/s4).
   Laufend: gates_f04.sh (check, modern-check KEEP gates_f04/modern_keep, Suite, render all) -> danach Modern-Bilder
   ansehen, ggf. modern-make; Bericht W6 §11 TORE_F04_PLATZHALTER füllen; Archiv pushen; Task #136 schließen.
   00:50 F-04 Tore: check 20/20+17/17, modern 6/6 (kein Neuaufnehmen), Suite 860/0; render_all läuft.
   K8 (Task #138, Eckhaus-Rückseite): Exporter 20c9776 (far_shift nur paris_corner; Haussmann-Block neu exportiert
   byte-gleich bis auf Schlüssel). Export _cache3d: far_faces 8 / kept 0, cuts 2, lod0 5687 / lod1 3430. Blender-Ansicht
   k8/view/sheet.jpg + mesh_sheet.jpg gut. k8/after.sh wartet auf "GATES F04 DONE": Bake, Import, Manifest, validate,
   Ansichten k8/shots (yaw 0/90/180/270, 12/22 h), dann gates_k8 (check, modern KEEP, Suite, render all) -> "K8 GATES DONE"
   in logs/k8.log. Danach: Ansichten ansehen, Doku modelle.md (Abschnitt 22/K8 + 26?), Bericht W6 §12, Commit Teil 2.
   03:20 F-04 FERTIG (#136): render all 33/33 (nach Container-Neustart wiederholt); Bericht §11 Tore gefüllt.
   K8: gebacken + angesehen (k8/shots/corner_100m.jpg, corner_sides.jpg: Rückwand 5 Achsen/5 Läden, rechts 4/4),
   Commit 3464880 (Assets, modelle.md §27, Vertrag A-34), gepusht. gates_k8: check 20/20+17/17, modern 6/6; Suite und
   render all laufen (k8/after.sh) -> Bericht §12 TORE_K8_PLATZHALTER füllen, Archiv pushen, Task #138 schließen.
   28.11. 05:10 K8 FERTIG (#138): Tore auf 3464880 alle grün (check 20/20+17/17, modern 6/6 + GLES 2/255 73,2 dB,
   Suite 860/0, render all 33/33); Bericht §12 Tore gefüllt. Welle 6 inkl. A-32, F-04, K8 damit abgeschlossen.
   NÄCHSTES: AU-C2 (Welt, Ambiente, Verkehr, Sirenen) – Vertrag Welle-6-Eintrag, D25–D30, §4.7; audio-modern.md
   §4.1/§13/§15; Bericht AU-C1. Platzhalter: ambience_audio.gd, traffic_extras.gd, env_acoustics.gd,
   assets/audio/modern/ambience/platzhalter_bed.ogg. Arbeitsordner m1/AUC2, Bericht deliver/AUC2.
   28.11. ~06:50 AU-C2 (#139) IN ARBEIT, Arbeitsordner m1/AUC2 (PLAN.md, env.sh, tools/: drive_c2.gd Probefahrt,
   worst_case2.gd, scenes.py, deliver.py, bausteine.py, bench.gd), Commits 18279dc/…/(3/n) auf wip/v080-welle6.
   Fertig: Generatoren ambience_synth.py/traffic_modern.py (deterministisch, 22,23/23 MB), Bausteine env/ambience/
   traffic, AudioFeed water/style/climate/features, Tests test_world_audio (146/0 audio_modern), QC OK, Breite
   auf MCar (wet 0,3), Hörproben deliver/AUC2 (rundfahrt_alle_szenen.mp3, klangbausteine.mp3, je Szene).
   Läuft/offen: unabhängige Code-Prüfung (Agent), Befunde einarbeiten, Doku-Entwurf m1/AUC2/doc_16.md in
   docs/audio-modern.md (§16 + Tabellen §4.1/§9/§10/§12/§13), Vertrag A-35, Bericht deliver/AUC2/bericht.md, Tore.
   28.11. ~07:25 AU-C2: Code fertig (Prüf-Befunde 1–11 behoben, Commit 17bda1c), Doku §16 + Vertrag A-35, Bericht
   deliver/AUC2/bericht.md (nur TORE_AUC2 offen), Hörproben final. Tore laufen: m1/AUC2/gates.sh (setsid; check,
   modern KEEP, run_tests, qc_det, render_all; .done-Dateien in m1/AUC2/gates) -> "GATES AUC2 DONE" in
   m1/AUC2/logs/gates.log. Nach Neustart: gates.sh neu starten (überspringt Fertiges). Dann TORE eintragen,
   Archiv, Task #139 schließen, Nutzer berichten.
   Nach Neustart: queue_ablmp.sh (A/B, Vorher-Bilder für N6) neu starten (überspringt Fertiges).
   (alt) Nach Neustart: queue_r5.sh, gates2.sh und queue_ablmp.sh neu starten (L2, R4, ab_c1/c2 FERTIG) (setsid nohup bash …); sie überspringen Fertiges.
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
