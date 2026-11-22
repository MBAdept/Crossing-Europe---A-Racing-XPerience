# STAND QA-RINT-BILD (QA zweite Montage M2, head 9b02f05)
Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_9927a373-337-2 (branch worktree-wf_9927a373-337-2, ff auf 9b02f05, .godot kopiert, import OK)
Basis-Worktree (detached 515dd51, import OK): $S/base  (am Ende als Worktree entfernen, --force)
Scratch S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-RINT-BILD
Deliver: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-RINT-BILD
Skripte: $S/sh (env.sh setzt XDG/TMPDIR/MESA), queue.sh <jobs> (A/B Kopf + Basis-Modern, .done je Job, restart-sicher),
  perf.sh/pqueue.sh <jobs> (qa_perf.gd, Zeitraffer 40, deck=1280x800; .done in $S/perf), occl.sh <tag> <root> <pos;pos> (qa_occl.gd)
  Alle schweren Jobs halten $S/heavy.lock (flock) -> nie zwei gleichzeitig. Untracked Kopien qa_perf.gd/qa_occl.gd im Worktree und in base (nie committen).
Neustart: Skripte einfach neu starten (setsid nohup ... &), .done ueberspringt Fertiges:
  queue.sh $S/jobsA.txt ; pqueue.sh $S/pjobs2.txt ; occl.sh struct <W> "<pos>" (siehe unten)

## Done
- Setup (ff, import), Basis-Worktree
- modern_sight --full: 6/6 OK (F2 max 0.596 Regen), path --full 2/2 OK  -> logs/sight_full_head.log, path_full_head.log
- A/B S1,S2,S3 (S1 mit Basis): S1/S3 gleich wie Arcade, S2 besser (Dach). Kopf=Basis bei S1.
- qa_perf.gd repariert (live ueber _gfx_state==0, ganzes perf_stats im JSON), compile OK in Kopf und Basis

## Doing (Nachfolger 2 seit 2026-11-22 08:07)
- Maschine stark belastet (andere Agenten nice 10/19): ein Modern-Bild ~6 min. Darum reduziert:
  queue.sh $S/jobsB.txt (47 Jobs priorisiert, Basis nur N1,N2N,KHH22), pqueue.sh $S/pjobs2.txt (Perf bei 640x360 / Deck 640x400,
  Zeitraffer 40; Zaehler sind aufloesungsunabhaengig, Bildzeiten nicht mit RINT vergleichbar), occl.sh struct (7 Positionen, qa_occl.gd
  mit RGB8-Fix; erster Lauf hatte Formatfehler -> verworfen). Alle drei laufen und teilen den Lock.
- S4 fertig (Kopf rosa getoent wie Arcade, Basis weiss) -> sheets/S4_00.jpg
- N1 fertig (Kopf: Schneestreifen, Basis ohne; sonst gleich) -> sheets/N1_00.jpg, N1_crop.jpg
- Perf: Zeitraffer 40 = 1,33 s Sim je Bild (470 m je Bild!), KH ganz in ~2,5 min. pjobs2.txt neu (19 Jobs: KH/DN je Preset Kopf+Basis,
  MEM 20 min ts 4, KH1 ts 1 Deck Kopf/Basis). qa_perf.gd: Zensus alle 10 Bilder, RSS ueber grep. Auswertung: python3 sh/perf_table.py perf
- head_KH_modern_deck fertig (alte Skriptfassung, Zensus nur 4 Proben -> KH2 wiederholt)
- occl struct: KH 14.3 / 77.4 / 88.0 OK (min 1.00/1.00/0.76); Grenze bremen_amsterdam 139.5: Testauto auf dem Standstreifen
  (+3.75) bei 70-100 m im/hinter dem Haeuschen (Haeuschen steht auf dem Standstreifen bei ~65-80 m) -> Sondenartefakt, mit GRZ A/B
  gegen Arcades Haeuschenlage pruefen. occl akorr (T1-T4, S0, S4) wartet. Bericht-Geruest in deliver/bericht.md angelegt.
- 09:35 laufen 5 Warteschlangen am Lock: queue.sh jobsB.txt, queue.sh jobsC.txt (C1T Tag), pqueue.sh pjobs2.txt,
  occl.sh akorr, clipq.sh cjobs.txt (2 Clips a 10 s). Neustart: jede einfach neu starten.
- Fertig: N2N (GT nachts hell-silber statt dunkelblaugrau; Regen gut; Basis ohne Regen), perf head/base KH deck
- Offene Pruefpunkte: C1 km 221 Haus verdeckt rechte Spur bei 260 m (C1T A/B klaert Arcade), Grenze Haeuschen auf Standstreifen,
  Nuernberg/Dresden kahler brauner Stadtboden, Dresden gelbe Seitenwand ohne Fenster (STB klaert)
- Bericht: deliver/bericht.md Abschnitte 0, 1.1, 1.2 (Tabelle), 2 (Kopf) geschrieben
- 11:00: occl akorr fertig (T1-T4,S0,S4 alles sichtbar; T4 260 m ausserhalb Bild). C1T: Arcade hat dasselbe Backsteinhaus -> kein neuer Befund;
  Arcade zeigt rechts vorne ein Hochhaus, das Modern fehlt (C1T_crop_r.jpg). U1 gleich. perf head KH high fertig (iu max 134).
  Clip hh_nacht_regen fertig (besser: nasse Strasse; popscan.py: 0 einseitige Spruenge Modern). clipq hatte stdin-Fehler (ffmpeg frass
  Jobdatei) -> behoben, Valik-Clip laeuft neu. AB_TIMEOUT=1500 in env.sh (C1T Modern lief in 600 s Zeitlimit).
- jobsB.txt ab Zeile 5 neu priorisiert (TS15N, GRZN, VALN, STB, KBN, DEV, C1, S5, T1, ...)
- 11:45: KHH22 fertig (Fenster nahes Haus 0,46x Arcade, Basis 0,76x). Valik-Clip fertig: BEFUND F-01 Ausfahrt Schnee:
  3 Bilder braun/schneefrei (ce_snow = snow*(1-tunnel01) in environment_rig.gd:385), dann 1 s Weissueberstrahlung 65 % weiss
  (EXIT_AFTER); Gotthard-Clip von RINT trocken 15-19 % vs Arcade 1-3 %. Bilder/Clips nach deliver kopiert, Bericht 2.2 geschrieben.
  golden.sh (Arcade-Goldens) wartet am Lock. perf: head_DN_deck fertig (collect station 4.11/road 4.09 ms = Lastspitzen?)

## Next
- Bilder ansehen (python3 sh/compose.py ab sheets IDs), Clips (tools/ab_clip.sh mit TMPDIR), occl T1-T4/C1/S0/S4, Perf, Speicher 20 min, Instanz-Census (check_instance_budget*), golden check am Ende, base-Worktree entfernen

## Pitfalls
- ab_shot nutzt TMPDIR fuer XDG -> env.sh setzt TMPDIR=$S/tmp
- Bash-Tool verweigert komplexe Befehle (Heredoc + git/worktree, Ketten) -> Write-Tool nutzen
- Plattenplatz knapp (7 GB frei am 22.11.)

- 11:53 GOLDEN arcade 20/20, arcade-ui 17/17 identisch (logs/golden_check.log) -> NICHT nochmal laufen lassen.
- TS15N fertig (Dachzone 0,77x Arcade). base DN deck fertig. qa_perf.gd hat jetzt Spike-Ortung (spikes[] im JSON).
  pjobs2.txt ab Zeile 8 neu: KH1 head, DN1 head/base, KH1 base (ts 1), MEM, ... . Auswertung sh/perf_md.py perf
- 12:17: fertig A/B: GRZN (besser, Haeuschen gleiche Lage wie Arcade), VALN (gleich/besser), STB (gleich; brauner Stadtboden = Arcade).
  perf: head KH medium/low, MEM (lief nur 150->365 km in 207 s wegen Zeilenversatz; RSS flach 1075-1077 MB, Orphans 0) -> MEMF (ganze
  Etappe Bern-Mailand ts 4) und head DN high am Ende von pjobs2 angehaengt. jobsB ab Zeile 10 neu: S0, ZIEL, S1_DECK, NUE12, KIEL22S, DEV, C1, T1, S5, N2_DECK...
  Bericht: Abschnitte 0-3 + Bildtabelle bis STB geschrieben; Befundliste/Leistung/Kurzfassung fehlen noch.
- 12:27: pqueue neu auf pjobs3.txt (Umschreiben laufender Jobdateien verschiebt den Leseversatz -> NIE wieder laufende Dateien umschreiben,
  stattdessen Queue beenden und mit neuer Datei starten). base KH high lief noch aus dem alten Lauf (perf.sh ohne .done).
  Bericht: Befunde F-01..F-07 geschrieben; offen: Leistung (Abschnitt 4), Kurzfassung, weitere Bildzeilen, Ergebnis.
- 12:48: head KH1 deck (ts 1, 900 s, 84,5 km): render() avg 2,50 ms (Budget Deck 1,5), Spitzen terrain 55 ms km 30.8, commit 17,7 ms km 74.6,
  vehicles 26 ms, bridge collect 4,1 ms; Speicher flach (RSS 1082->1087 MB in 14 min, Orphans 0); iu max 141. Basis KH1 folgt (pjobs3 Zeile 4).
  S0 fertig (Startportal besser; Arcades grosse Eiche links fehlt -> in F-03). ZIEL laeuft.
- 13:13: ZIEL, S1_DECK fertig (gleich; Deck fuellt 16:10). head DN1 (ts1) fertig: render 2,85 ms, Einzelspitzen lights 159 / vehicles 138 /
  flares 143 ms (vermutlich Verdraengung, Basis DN1 laeuft zum Vergleich), station collect max 2,02, commit max 3,24, RSS flach 1078.
  Plan: bis ~14:05 base DN1 + base KH1 abwarten, dann Queues stoppen (pkill queue.sh pqueue.sh), Bericht fertig, Basis-Worktree entfernen.
- 13:48: base DN1/KH1 fertig (Spitzen an denselben km wie Kopf, Kopf 2-3x schwerer). pjobs4 (DN1b Wiederholung Kopf) laeuft/wartet.
  NUE12 fertig (deutlich besser). Bericht fast fertig: offen Kurzfassung oben, Abschnittsreihenfolge (4 vor 5), DN1b-Ergebnis.
  Danach: queue.sh/pqueue.sh beenden, base-Worktree entfernen (git worktree remove --force $S/base), qa_*.gd im Worktree loeschen.
- 13:57: A/B-Queue beendet (KIEL22S letzter Job, besser). Basis-Worktree ENTFERNT. Bericht fertig bis auf DN1b-Ergebnis (laeuft bis ~14:10).
  Danach: DN1b in F-08 eintragen, Aufraeumen (xdg, tmp, mesa, clips-Duplikat, qa_*.gd im Worktree), StructuredOutput.
- 14:15 FERTIG: DN1b (Wiederholung) eingetragen (138-159-ms-Stoesse nicht reproduziert; render +28-38 % reproduziert).
  Alle Queues beendet, Basis-Worktree entfernt, qa_*.gd aus dem Worktree geloescht (git status leer), xdg/tmp/mesa/clips-Duplikat geloescht.
  Bericht komplett: deliver/QA-RINT-BILD/bericht.md. Nur noch StructuredOutput abgeben.
