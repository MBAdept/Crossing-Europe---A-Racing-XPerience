# M2INT – Stand (Übergabe)

- Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_438996b0-243-1
- Branch: worktree-wf_438996b0-243-1 (push nach origin wip/v080-m2int nach jedem Commit)
- Start: 2026-11-12 02:52 UTC, ff auf 350b071 (Basis), .godot kopiert, Import
- Hilfsskripte: m1/M2INT/sh/ (rebuild.sh; tests.sh; ab.sh; absheet.sh; clips.sh; gates.sh <schritte>; meas.sh;
  reexport.sh; export_olives.sh; copy_caches.sh; *imports.py; showroom_paint.py),
  Logs m1/M2INT/logs/, Gates m1/M2INT/gates/, Proben m1/M2INT/probe/, Messbilder m1/M2INT/meas/, A/B m1/M2INT/ab/ und
  m1/M2INT/absheet/, Kritik-Werkzeuge m1/M2INT/kritik/
- Bericht-Entwurf: deliver/M2INT/bericht.md (Abschnitte 1, Notizen 2–7 stehen; fehlt: 8 Klang, 9 Goldens, 10 ZS1,
  Bild-Urteil, Gates, Abweichungen/Vertragsfragen/Nächste)

## Erledigt (Commits, alle gepusht)
- aa9a469 Merge AS2R; da7483a Lkw retro; 632b411 check_vehicles kasten/leistung
- 0e0f45c Merge AS3R (+ test_props); afe1c8d Merge AS4R; d493c6a Merge SOUND
- 9477629 UI-Klänge Modern; b341df8 Fernboden unter Wasser
- f040637 LOOK in ModernMaterials, Flocken aus; 18033b3 olive_b/Bus re-export + Determinismus
- 9b0ab34 Doku modelle.md (ferne Stufen gemessen, Olive, Showroom bleibt false)
- Messungen (logs/meas_*): showroom (alle false), kritik (Scheiben/Kennzeichen ok, Karoband Blau −14), olive_b −0,2/
  +0,5/+0,7 %, pop (SUV 7,2 / Sport 8,1 / Polizei 13,1 % je Bild), texmem Modern 103,6/97,5 MB vs Arcade 225,8/214,6,
  census Fahrzeuge ≤ 107/128, Köhlbrand Tag+Nacht ok (kein Seil über Spur; Elbphilharmonie nachts in Modern dunkel?)

- c317625 Wahrzeichen nachts bis landmark_far_m (props.far_reach, billboard/baked lights-only, check wahrzeichen
  nachts) – A/B ab/koehl_nacht3 zeigt Elbphilharmonie + Michel beleuchtet

- A/B-Bögen FERTIG (absheet2/, aus snap = c317625), angesehen (quad/: Arcade|ZS1|M2INT|Diff), nach
  deliver/M2INT/ab_boegen/ kopiert (+ vergleich_zs1_*). Urteil: M2INT ≥ ZS1; offen (alt, R4/R5): kein Regen/Schnee in
  der Luft, fehlende nahe Bäume (T4 rechts, C1 Baum, S4 Birke), Spielerauto nachts heller; neue Modelle Sportwagen
  (19:30 satter), GT (Regen weißer/flacher, Heckscheibe mittags blau)

- Gates keys/geometry/audio/validate/bake auf c317625: alle OK (gates/summary.txt), im Bericht §4 eingetragen
- Bericht umsortiert: 1 Merges, 2 Notizen 2–8, 3 Bilder, 4 Gates (fehlen: 9 Goldens, 10 ZS1, Rest-Gates, 5 Abweichungen)

- Bus-Pop gemessen (4,7 %), voller Testlauf Nr. 1 (c317625): 734 Tests 0 Fehler, 148 CHECK OK (899 s)
- 87b0882 Doku Stufenwechsel; b2c6b52 VPBR_STATIC (Überlauf Shader-Puffer auf Waldetappen behoben, check
  instanzen_wald neu, T1 pixelgleich, 0 Ablehnungen) – gepusht
- erster Land-Clip abgebrochen (vor dem Fix, 55 Ablehnungen); snap/ neu = b2c6b52

- Land-Clip FERTIG: deliver/M2INT/clips/dortmund_frankfurt_km121_wald_doerfer.mp4 (23 MB, 30 s, 0 Ablehnungen,
  aus snap = b2c6b52; Bilder m1/M2INT/clipframes/land_frames.jpg angesehen: gleichwertig, Sonne fehlt, nahe Fichte
  rechts fehlt wie an T4)

- Render-Vorlauf b2c6b52: 15/18; light_base schatten (ZS1 behebt), props_spiegel + vehicle_standin laden (vom
  Inhalt überholt) -> af5fbe1 angepasst, beide einzeln OK; gepusht
- Leitung hat neuen Workflow wf_m2k_zs1_wasser (FIX_WASSER: Elbe unter Köhlbrand) -> ZS1_FERTIG kommt später;
  Frist 12:00 UTC

- Gates auf af5fbe1: sight 6/6+2/2, ERGEBNIS 3x identisch, Autopilot K–H + Dresden–Leipzig Exit 0, texmem,
  Builds (Linux 184,7 MB geschätzt, Win-Zip 194,5 MB), Smoke Linux+Windows(Wine) OK, Oliven aus pck OK
- Fallback-Start-Clip (ohne ZS1) -> deliver/M2INT/clips/kiel_hamburg_start_tag_ohne_zs1.mp4
- **ZS1_FERTIG bis 12:00 UTC NICHT da -> ohne Merge abschließen** (Bericht Notiz 10)

- 49f221e Modern-Goldens neu (Bilder pixelgleich mit den angesehenen golden_pre) – gepusht
- Endstand 49f221e: import 0 Fehler; run_tests 735/0, 148 CHECK OK (903 s); golden check arcade 20/20, ui 17/17

- render all auf 49f221e: 17/18 (nur light_base schatten rot, ZS1 behebt)
- ZS1_FERTIG erschien erst 12:47 UTC (39849f0) – nach Frist, NICHT gemergt (Vorgabe); Leitung: „folgt im nächsten
  Schritt“. Merge-Plan: Bericht Notiz 10, Nachricht msg_merge_zs1.txt
- Bericht fertig (deliver/M2INT/bericht.md), Scratch aufgeräumt (snap, wineprefix, Bilder-Zwischenstände gelöscht)

## FERTIG – Ergebnis abgegeben (StructuredOutput)
- Bericht fertig, STAND, push, aufräumen (snap/, wineprefix_m2int, smoke_pre, xdg_*), StructuredOutput
- danach: WT=snap clips.sh land; vor ZS1 evtl. Render-Prüfungen + sight/path als Vorlauf
- Lead-Task #72: ZS1 behebt evtl. selbst „Elbe unter Köhlbrandbrücke“ (= mein b341df8) -> beim ZS1-Merge Konflikt in
  far_ground.gd möglich; eine Lösung behalten
- REGEL: Renderjobs nur aus snap/ laufen lassen, dann darf im Worktree weiter editiert werden

## Als Nächstes
- Bilder ansehen, billige Fixes; vor ZS1 noch: gates.sh keys geometry audio (generator-/klangseitig)
- ZS1_FERTIG (m1/lead/ZS1_FERTIG) -> merge --no-ff; dann golden.sh modern-make (Bilder ansehen!), clips.sh both,
  gates.sh import tests golden render sight validate bake ergebnis autopilot texmem builds, export_olives.sh,
  smoke (tools/smoke_modern.sh für Windows-Start Modern), pck_report
- deliver/M2INT: A/B-Bögen (jpg), Clips, Bericht

## Fallstricke
- ZS1_FERTIG fehlte bis 04:30 -> nice -n 19, ein Prozess
- Bash-Tool lehnt verkettete git-Befehle/Heredocs teils ab -> Skripte in sh/, Edit-Tool
- meas.sh kopiert kritik_render.gd nach tools/kritik/ und löscht es – vor Commits prüfen, dass tools/kritik fehlt
