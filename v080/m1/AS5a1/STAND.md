# AS5a1 – Stand (Übergabe)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-1
- Branch: worktree-wf_db8ba6cd-508-1 (push: git push origin HEAD:refs/heads/wip/v080-as5a1)
- Basis: 6e484056ec87e2fa614061000a362feb2b5a6db8 (ff-merge erledigt), .godot kopiert + Import OK,
  _cache3d von AS4R (wf_aad8d49e-fb4-6) kopiert

## Commits (gepusht nach wip/v080-as5a1)
- ecadb85 Bauer "city"; bef968b Licht wie Scheiben, Katalog aller elf, Hook close3d (props_cities);
  dc416e1 flache lod1, verdeckte Giebelschrägen, Rückwand-AO, light_mul (Büroturm-Foyer)

## Erledigt
- Zählung Rennen (census_race.log): german_house 282, fachwerk 99, fachwerk_b 95, mietshaus 77, gruenderzeit 72,
  hanse_gabled 54, barock 32, speicher 10, office 7, kontor 4, crane 3. Tönungen: house #e8b8a4,
  mietshaus #e0b09c/#f6eee2, gruenderzeit #f6eedc/#ece4d0
- check_sprite_geometry nach close3d: 86 identisch, 0 ANDERS (geom1.log)
- Proben r0..r3 (Halbatlas) german/old/hanse, Bilder in shots/

## Nachfolger 2 (13.11. 05:30)
- Kette war 21:02 fertig (alle elf echt exportiert), Container-Neustart danach; Exporte als 92c0084 WIP committet + gepusht
- jetzt: Bilder der echten Exporte ansehen (Runde 5), Mängel, Messungen, Gates, Lieferung

## Vorgänger (19:45)
- Commits: 02537f6 Dichte, 052c49d bake_samples 4, 33e78ce Garten-Gewicht + Lampenoberseiten, 09d0a7b german-Assets
  (VERALTET), a5315cd Fix: nur Lampen der Liste öffnen (Ornamente/Gauben blieben ganz)
- Kette läuft (setsid, chain.sh): german -> real_german.log, german_old -> real_old.log, hanse -> real_hanse.log
  (Ende ~22:40); nach jedem Stil: validate, commit + push (msg_german.txt; old/hanse noch schreiben)
- docs/modelle.md: Abschnitt 20 als Entwurf angehängt (Platzhalter TABELLE/EINORDNUNG/ZAHL) + Statuszeile, NICHT committet
- Messungen german (alter Stand): texel_probe Normalen in Godot invertiert (fern+X = Straße), Geländer mipcov mip4 0,29-0,59

## Als Nächstes
- Bilder r4 ansehen; danach cities3d.py EINFRIEREN (Änderung = alle 11 neu exportieren)
- echte Exporte (cycle.sh real ...) in Reihenfolge Häufigkeit; commit je Stil (german, german_old, hanse)
- AS4-Modelle mit props_cities im Schlüssel neu exportieren (bridge_*, houseboat) -> byte-gleich?
- Messungen, Gates, Lieferbilder, bericht.md, docs/modelle.md

## Werkzeuge (scratch)
- cycle.sh probe|full|real <ids>   probe.py (Halbatlas, Schlüssel "debug")   views.sh <tag> <models> <x>
- install_tools.sh -> tools/kritik/ (UNVERSIONIERT) - VOR run_tests.sh LÖSCHEN (rm -rf tools/kritik)
- share.py <wt> 'props/city_*' (Archivanteil)

## Fallstricke
- nice -n 19, ein Worker, vor Blender/Godot free -g prüfen (< 3 GB available: warten); Last ~20 (andere Agenten)
- buildings3d.py NICHT ändern (Schlüssel der AS4-Modelle)
- Probe-Dateien in assets/models/props/city_* und manifest.json NICHT committen (Halbatlas, Schlüssel "debug")
- CE_THREADS=3 für alle echten Exporte UND den Determinismus-Lauf (gleich halten)
- Skripte: measure.sh texel|lods|spark, k4.sh, ab_all.sh, mipcov.py (Geländer-Deckung je Mip)

## Nachfolger 3 (15.11. 08:05)
- Container-Neustart nach 13.11. 05:36: chain2.sh (deliver old/hanse, Tönung, Messungen) lief NICHT (keine Logs)
- Worktree unverändert (nur tools/kritik/ unversioniert), HEAD 92c0084 = origin/wip/v080-as5a1
- jetzt: Lieferbilder german ansehen (Runde 5), dann chain2-Teile einzeln
- 08:15 Runde 5 (echte Exporte) german + altstadt angesehen: keine Mängel, die einen Neu-Export lohnen (Foyer Büroturm
  nachts flach = bekannt, 7 Vorkommen). validate --report grün (validate.log), budget.py: Netze 0,79 MB, Texturen 5,27 MB Archiv.
  AS4-Modelle: Schlüssel unverändert (stale.py: houseboat/bridge_* aktuell), keine Dateien außerhalb city_* geändert.
  mipcov echte Atlanten: mip1-3 1,1-1,4, mip4 0,29/0,59.
- Plan: deliver hanse (läuft, Hintergrund) -> chain3.sh (tint,texel,lods,spark,ab,clip) -> geometry -> determinism
  (crane, office, kontor erneut erzwingen, CE_THREADS=3) -> rm tools/kritik -> run_tests -> golden check/modern-check
  -> bericht.md, docs Abschnitt 20 Platzhalter füllen -> commit/push
- 08:25 deliver altstadt + hanse fertig (Bilder in deliver/AS5a1). chain3.sh läuft im Hintergrund (Log chain3.out:
  outline,tint,texel,lods,spark,ab,clip; Ergebnisse meas_*.log, ab/, clip.log). Danach: det.sh (Determinismus), Gates.
- 08:58 RUNDE 6: Fehler gefunden (Lod-Bilder): Rundbogentüren in lod0 rechteckig (Log setzt arch, Türpfad las nur top),
  Torbogen Turmhaus (2,8 m) als geripptes Garagentor. Fix in cities3d.py committet (WIP, gepusht).
  Echte Exporte laufen: Teil A (fachwerk_b, fachwerk, barock, gabled) -> real6_a.log; danach Teil B (übrige 7, müssen
  BYTE-GLEICH bleiben = Determinismusbeweis) mit CE_THREADS=3. Danach: Messungen lods/outline/spark für die 4 neu,
  deliver-Bilder altstadt/hanse neu, tint, ab, clip, Gates.
- Messungen bisher (alte Exporte, gültig für die 7 unveränderten): meas_outline.log (IoU >= 0,987, Kran 0,922),
  meas_texel.log, meas_lods_*.log (Wechsel 60 m: 2-32 % Pixel), meas_spark.log (Flimmern Modell 0,3-1,3 % vs Sprite 0,0-0,6 %)
- chain3 abgebrochen VOR ab (TaskStop). tint_scene.gd repariert (Typfehler Zeile 44), Kopie in kritik_copy/.
- 10:08 Teil A fertig + committet 371c8de (gepusht). Teil B läuft (crane, office, kontor, speicher -> real6_b.log;
  danach git status: diese 4 Ordner müssen UNVERÄNDERT sein = Determinismus). Danach (alles nacheinander):
  deliver_style.sh altstadt + hanse neu (Türen), measure lods old/han neu, chain3.sh tint, ab, clip; geometry; Gates.
- Bericht-Bausteine: bericht_kopf.md, bericht_teil_mess.md, bericht_teil_einordnung.md, runden_final.md,
  tab_*.md, budget_table.md (budget.py neu laufen lassen nach Teil B)
- 10:33 Teil B fertig: crane, office, kontor, speicher neu exportiert -> git status SAUBER (byte-gleich) = Determinismus
  + Türfix ändert unbeteiligte Modelle nicht. chain4.sh läuft (Bilder altstadt/hanse, lods, tint, ab, clip -> chain4.out).
  check-keys braucht > 15 min (Timeout) -> im Hintergrund ohne Timeout neu.
- 11:00 8b7740e gepusht (docs Tabelle). check-keys OK (checkkeys.log). chain4: Bilder altstadt/hanse neu (Türen ok),
  lods neu (meas_lods_*; vorher-Kopien *_vorher), tint OK (toenungen.jpg). Läuft: ab (ab/, ab_all.log), dann clip.
  Danach: geometry (check_sprite_geometry --only props --jobs 1), rm -rf tools/kritik, run_tests.sh, golden check,
  golden modern-check (ggf. modern-make), validate --report, bericht (assemble.py), Lieferbilder A/B kopieren.
- 11:47 chain5: geom OK (86 identisch), run_tests 1 Schritt rot: 2 Audio-Zeittests (test_engine3_checks thread: 6 Hänger
  à 400 ms -> 40 Aussetzer; test_music_checks race) - Last, nicht meine Dateien -> gefiltert wiederholen.
  golden check 20/20 + 17/17 identisch. modern-check läuft (KEEP=golden_modern/). A/B: abgebrochen nach kh_high_h12
  (Modern-Lauf > 600 s für 2 Bilder) -> verkleinert neu: SHOTS=2, kh/hh/kw × (high 12, high 22, medium 19.5).
- 12:35 modern-check 4/6 (s4, s5 = meine Modelle, angesehen) -> Liste aus KEEP-Bildern, commit 63544b6 gepusht.
  tools/kritik GELÖSCHT (vor run_tests). chain6 läuft: ab (8 Läufe, ab_all_{1,2,3}.log), clip, retest engine/music.
  Danach: A/B-Bilder nach deliver kopieren (ab_<stadt>_<preset>_<zeit>.jpg), bericht via assemble.py (+ bericht_gates.md,
  bericht_ab.md schreiben), validate --report final, STAND, Ergebnis.
- 13:30 A/B fertig (9 Bilder in deliver, ab_*.jpg). clip läuft, dann retest. bericht_ab/gates teilweise gefüllt.
- 14:01 chain6 nach 2 h Hintergrundlimit abgebrochen (Clip-Modernlauf halb). Jetzt: chain6.sh retest (chain6b.out),
  danach Clip neu (chain3.sh clip, eigener Hintergrundlauf). Dann assemble.py, Ergebnis.
- 14:10 retest: engine OK, music rot (239,2 ms, kopflos arcade, nicht meins). bericht.md zusammengesetzt (assemble.py 63544b6), fehlt nur {{CLIP}}. Clip läuft (chain7.out, clip.log).

## FERTIG (15.11. ~14:55) – Endstand 63544b6 auf origin/wip/v080-as5a1
- Clip fertig (fahrt_wuerzburg_altstadt.mp4, 600 Bilder, Autopilot 50-128 km/h), bericht.md vollständig in deliver/AS5a1
- Gates: validate OK, geometry 86/86, check-keys OK, Determinismus (4 byte-gleich), golden 20/20 + 17/17,
  modern 4/6 -> Liste neu (63544b6), run_tests: nur test_music_checks rot (kopflos arcade, nicht AS5a1)
- Scratch aufgeräumt (shots-PNGs, mesa, xdg_tests gelöscht). tools/kritik ist gelöscht (Kopien: AS4R-Scratch, kritik_copy/)
- Ein Nachfolger muss nichts mehr tun außer ggf. das Ergebnis erneut melden.
