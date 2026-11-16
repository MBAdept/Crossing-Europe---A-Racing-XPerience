# AS5a2 STAND (Stadthäuser Teil 1, Charge 2: dutch, belgian, french, paris, swiss)
- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_db8ba6cd-508-4
- Branch: worktree-wf_db8ba6cd-508-4 ; push: git push origin HEAD:refs/heads/wip/v080-as5a2
- Base: 7153381 (ff-merge erledigt), .godot kopiert + Import OK, _cache3d von AS5aR1 (wf_...-3) kopiert
- Scratch: m1/AS5a2 (env.sh, k5.sh, v2.sh <tag> <items> close|dist|lods, geom.sh <tag>, tools/cycle.sh probe|real)
- tools/kritik/ UNVERSIONIERT (install_tools.sh) -> vor run_tests.sh LÖSCHEN

## Zensus (AS5a1 census_all.log, Platzierungen netzweit)
french_sud 588, belgian_terrace 315, french_maison 209, french_immeuble 202, dutch_terrace 130 (Tönung #ead6cc 50x),
belgian_stone 96, paris_haussmann 55, swiss_chalet 54, dutch_canal 51, swiss_laube 46, dutch_canal_b 22, paris_corner 8
Reihenfolge Stile: french, belgian, dutch, swiss, paris

## Erledigt
- Katalog: 12 Einträge im AS5a-Block (zweites MODELS.update "AS5a2")
- Hooks close3d (props_cities): dutch_canal (+_canal_house side/close3d), dutch_canal_b, belgian_terrace,
  belgian_stone, french_immeuble, dutch_terrace, swiss_laube
- cities3d.py: weights["solid"] (Baumkronen: Gewicht unabhängig von Richtung, nie versteckt) – Fix weiße Kronenflecken
- Commit 1 (WIP Katalog+Hooks+solid+rail_module) gepusht; geom h1: 86/86 identisch
- Runde 1 (Proben sud, belgian_terrace, maison, immeuble; shots/r1): gut; Kronenflecken weg; Fenstergitter verdeckten
  Fenster -> openings.cover_skip; Immeuble lod1 bei 250 m rosa-lila (prüfen: lods-Bild)
- cities3d: cover_skip, chamfer (Eckhaus) - noch nicht im Commit
- docs-Entwurf: doc21_draft.md
- Runde 2/3 (Proben aller 12, shots/r2a r2b r3): gut; Fixes cover_skip (Blumen, Traufe), chamfer, schräge Geländer
  im Modul, smooth (Blumen), Haussmann-Gewichte; CODE EINGEFROREN mit 93e5031 (gepusht)
- Stufenwechsel 60 m (Proben): 14-16,5 % Pixel, Helligkeit +0,1..0,4 %
## Jetzt (02:07)
- chain_real.sh (setsid, logs/chain_real.out): echte Exporte je Stil french, belgian, dutch, swiss, paris,
  nach jedem Stil v2.sh real_<stil> close dist. Fortschritt: grep -E "STYLE|EXPORT" logs/chain_real.out
- nach jedem Stil: validate, git add assets/models/props/city_<stil>* + manifest, commit + push
- WARTEND gestartet (setsid): chain_b1.sh (wartet auf chain_real; Charge-1 + Brücken + Hausboot neu, logs/chain_b1.out),
  chain_meas.sh (wartet auf chain_b1; validate contact lods spark outline tint mip -> shots/fin, logs/fin),
  chain_ab.sh (wartet auf chain_meas; A/B pa am br tl (hoch 12/22, mittel 19.5) + be hoch 12 -> ab/; Clip Paris -> deliver)
  Nach Neustart: Ketten sind weg -> einzeln neu starten (NOWAIT=1 ...)
- 02:50 french committet (abec2ad), belgian committet (63ca0ef), gepusht; Manifest erst mit dem letzten Stil
- Beobachtung: lod1 bei 250 m heller/entsättigt (Rahmen+Ringe weiß) - im Rennen (A/B) beurteilen
- docs/modelle.md Abschnitt 21 eingefügt mit Platzhaltern TABELLE/GEOMETRIE/EINORDNUNG (vor Commit füllen!)
- 03:20 dutch (f435fd9), swiss (60462fa) committet + gepusht; paris läuft; danach chain_b1 automatisch
- Bericht-Bausteine: bericht_kopf.md, bericht_pipeline.md; tools/doctable.py (Tabelle Abschnitt 21)
- 03:45 paris + Manifest committet (02d93cb). ALLE 12 ECHT. docs Abschnitt 21: TABELLE gefüllt (nicht committet),
  GEOMETRIE/EINORDNUNG noch Platzhalter
- Kette: chain_b1 (läuft seit 03:42) -> chain_meas -> chain_ab -> chain_final (det geom keys tests golden modern;
  logs/gate/*, golden_modern/ = Bilder der Modern-Goldens; danach ggf. tools/golden.sh modern-make NACH Ansehen)
- 04:00 german_house byte-gleich (erste Bestätigung). deliver.sh (Lieferbilder) erstellt + teils gelaufen.
- Bekannter Mangel (nicht behoben, Code eingefroren): Eckhaus-Abschrägung: Auslage im Schaufenster mit
  diagonalen Streifen (_display_mat liest u = x/y, nicht (x-y)/sqrt2) -> notes_for_next
- docs: GEOMETRIE + Tönung gefüllt; EINORDNUNG noch Platzhalter
## Danach
- Charge 1 (11) + bridge_lamp/pylon/pylon_bare/truss_arch + houseboat neu exportieren -> byte-gleich? (git status)
- Messungen (lods, spark, tint dutch_terrace #ead6cc, texel), ab_all.sh (pa am tl), Clip, Gates, Doku, Bericht
## Als Nächstes
- Bilder ansehen (v2.sh), Mängel, Runde 2; dann echte Exporte je Stil, commit+push
- AM ENDE: alle 11 Charge-1-Modelle + bridge_lamp/pylon/pylon_bare/truss + houseboat neu exportieren (Schlüssel
  enthält props_cities.py/cities3d.py) -> müssen BYTE-GLEICH sein
## Fallstricke
- Probe-Dateien (Halbatlas, Schlüssel debug) NIE committen; nur echte Exporte (cycle.sh real)
- nice -n 19, ein schwerer Job, free -g >= 3
## 04:50 RUNDE 5 (nach chain_b1: Charge 1 + Brücken + Hausboot BYTE-GLEICH, 0 Dateien)
- validate rot: canal_b extent_m.left 14,36 gegen Sprite 13,96 (Flanken-Kranzgesims bis hinten) -> props_cities:
  Gesims endet 1 m vor der Rückwand (berechnet 13,98). cities3d: Auslage der Eckhaus-Abschrägung u=(x-y)/sqrt2.
  Katalog: Maashaus bar_w 0,11 (Kreuzstock). Ketten meas/ab/final GESTOPPT.
- => ALLES NEU EXPORTIEREN (12 + 16): 9 eigene + 16 fremde müssen byte-gleich bleiben; canal_b, corner, stone neu
- ab0/: ein A/B Paris hoch 12 Uhr (Rennen-Look prüfen)
- 04:58 Code-Fix committet 771b079 (gepusht). A/B Paris (ab0/) gut: Modern deutlich feiner, keine Blässe im Rennen.
- chain_r5.sh LÄUFT (setsid, logs/chain_r5.out): geom r5 -> canal_b/corner/stone echt + validate + Bilder real_r5 ->
  übrige 9 eigene (GITSTATUS2 muss 0 sein) -> 16 fremde (GITSTATUS3 0) -> chain_meas -> chain_ab -> chain_final
  (alles NOWAIT). Danach: Modelle canal_b/corner/stone + Manifest committen, Goldens ansehen, Bericht.
- 05:25 geom r5 86/86; canal_b/corner/stone committet adef9df (validate grün); GITSTATUS2 = 0 (9 eigene byte-gleich)
- läuft: 16 fremde (Charge 1 + Brücken + Hausboot) -> dann meas, ab, final automatisch
- Lieferbilder: deliver.sh (Teil 1 gelaufen) + runde5-Bilder; nach meas: deliver.sh erneut
- 06:48 GITSTATUS3 = 0: Charge 1 + Brücken + Hausboot byte-gleich nach Code 771b079. chain_meas läuft, dann ab, final.
- 07:10 docs Abschnitt 21 fertig + committet (3c5e37a). chain_meas fertig (fin/: Kontaktbögen, lods, spark, tint, mip;
  Werte im docs). Outline falsch aufgerufen -> als erster Schritt in chain_final.sh eingetragen (k4_scene, IDs ohne @x).
- läuft: chain_ab (A/B pa am br tl + be, Clip Paris), danach chain_final (outline det geom keys tests golden modern)
- Mängel notiert: Eckhaus-Rückseite blind (keine Spiegelwand), rechte Flanke Halsgiebelhaus blind
- Danach: deliver.sh erneut, A/B-Bilder kopieren (rennen_*), Goldens ansehen, ggf. modern-make + commit, Bericht
- 07:35 Nacht Paris A/B: Läden in Modern dunkler als Arcade (beleuchtete Ladenpixel Mittel 124 gegen Arcade 207;
  Fenster 210). Ursache: _display_mat Licht ~40 % eines Fensters. NICHT behoben (Code -> voller Neuexport 5 h; gleiche
  Formel in Charge 1) -> als schwächster Punkt melden, Vorschlag shop_glow ~1,6 für beide Chargen in der Nacharbeit.
- 08:30 chain_ab fertig (13 A/B exit 0, 0 Fehlerzeilen; Clip fertig, aber Autopilot fuhr 68-136 km/h).
  chain_final läuft: outline fertig (IoU 0,945 Chalet ... 0,999; Bild umrisse_sprite_gegen_modell.jpg geliefert),
  det stone BYTEGLEICH; dann chalet, sud, geom, keys, tests, golden, modern.
- chain_clip2.sh wartet auf chain_final und dreht den Clip neu mit --autopilot-target=50 (clip2/ -> deliver ersetzen).
- Berichtsteile gefüllt: mess (DOCTABELLE, UMRISS), einordnung (Mängelliste). Offen: gates (GEOMFINAL KEYS DET TESTS
  GOLDEN MODERN ABFEHLER), andere (MESS_LODS), kopf (ZUSAMMENFASSUNG, HEADCOMMIT), Zusammenbau bericht.md.
- 10:05 FERTIG. chain_final: outline IoU 0,945-0,999; det 3x BYTEGLEICH; geom 86/86; check-keys OK; run_tests
  749/0 + 16 Suiten OK; golden 20/20 + 17/17; modern-check 6/6 identisch (kein modern-make). validate am Endstand OK.
  AS4-/house-Eingaben + Ordner: diff leer. Clip neu mit --autopilot-target=50, geliefert + Standbilder.
  bericht.md im Lieferordner (assemble.py). Großer Scratch gelöscht. Endstand 3c5e37a = origin/wip/v080-as5a2.
