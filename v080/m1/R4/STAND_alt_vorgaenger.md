# R4 – Licht, Nacht, Wetter – STAND (Übergabe bei Neustart)

Worktree: /home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_fd1de4ee-28b-1
Branch:   worktree-wf_fd1de4ee-28b-1 (Basis 6e484056ec87e2fa614061000a362feb2b5a6db8 = origin/wip/v080-m2int)
Sicherung: git push origin HEAD:refs/heads/wip/v080-r4 nach jedem Commit (nie force)
Scratch: /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/R4/
Abgabe:  /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/R4/
Basis-Kopie (git archive 6e48405, importiert): <scratch>/m1/R4/base  (für Vorher-Bilder und Leistungsvergleich)
Skripte: <scratch>/m1/R4/sh/{pos.sh (Positionen), ab.sh (ein A/B-Paar, WT=… wählt Baum), batch.sh, baseline.sh}
Bilder: <scratch>/m1/R4/shots/{base (Vorher N1,N2,N2N), v1 (erste R4-Bilder)}

## Erledigt (Commits)
- 47566b8 set_zone(kind, amount) + Test + Doku §15.1 (gepusht)
- 818816c WIP: weather.gd (Regen/Schnee zustandslose GPU-Teilchen, Gischt), particles_rain/snow, spray shader,
  flare_streak (Spiegelung Rückleuchten/Laternen nass), road.gdshader Fresnel-Himmel (ce_sky_top/horizon Globals),
  Blaulicht-Omni + Kegel (lights.gd beacon_of), beam_at(), Sonnenscheibe an Arcades Stelle (sky_palette),
  test_light_pool, test_weather (gepusht)
- b9484fc Schneewälle, Schnee auf Requisiten, Tunnelausfahrt-Glare, check_light_cap (OK), check_night, check_weather
- 9a5ffe4 Mond ≥ 55°, Fahrbahn nachts +8 %, Lack Halbkugel-AO + Fill im Schatten, lod0-Überblendung (Glas xfade)
- aa08899 Spiegelung auch Rolle "rear" (Modelle), Doku §15.9 (gepusht)

## Gerade (17:05 UTC)
- check_weather teilchen/gischt/nass/tunnel/schneewall OK (rc/check_weather.log, nass erneut OK nach "rear").
- check_night (17:00, aa08899): fahrbahn OK (N1 Modern 0.2775 / Arcade 0.2644 = +4,9 % medium und deck, 652 Proben);
  verdeckung OK (Kuppe 346 m 0 px, davor 38451; Sattelzug 0 px, ohne 14391); blaulicht OK (22 h 12804 px, 7848
  blauer, Punktlicht an; 12 h 1382/1130, Punktlicht aus); spielerauto FEHLER: kompakt 0.80×, GT 0.55×, Limousine
  0.35× (Arcade 0.214/0.191/0.166) -> Nacht-Füll-Licht: fill_night 0.6 + neuer Klarlack-Schimmer fill_sheen 0.25
  (vpbr, VEHICLE_LOOK); Sonde (tests/race3d/render/fill_probe_tmp.gd – NICHT committen, löschen!) zeigte
  1.3/0.1: 1.09/0.96/0.74, 1.0/0.3: 1.15/1.06/1.04.
- KBN Pylon (v4, high, 22 h): Region x500–780 y150–350 Rec.601 Arcade 59,7, Modern 55,4 (−7 %) -> 0,45 bleibt.
- c3afd5c Nacht-Füll-Licht (spielerauto OK 1,06/0,92/0,94); 8ceb281 Ausfahrt 60/45/40 % über 60 m, Füll-Licht im
  Tunnel 0,3 ohne Schimmer (fill_tunnel; TEXIT v5 zeigte graue Limousine im Tunnel), check_weather_tabelle.gd eigene
  Datei (.uid fehlt noch -> nach Import committen!), test_exit_ramp.
- Senkrechte Flächen: C1 Fassade (200,180)-(520,400) −2,2 %; DEV Portal −14/+2/+17 %; KBN Pylon −7 %.
- b9574c2 Laternen-Spiegelungen × Fresnel am Spiegelpunkt (C1RN zeigte orangen Fleck ums Auto), test_lamp_streak_fresnel.
- N2 (16 h Regen) GT: Stoßfänger Mittel +13 %, p75 +34 % gegen Arcade (vorher +53 %) – ehrlich melden.
- tabelle OK (0,90–1,01 × / Kontrast 0,74–1,17 ×, 933 s) -> fe70c27 zwei Dateien (klar/Regen, Schnee).
- d1181fe Glare-Viereck mind. 1,5 m vor dem Spielerauto (TEXIT v6: Auto im Weiß verschleiert).
- 32e23eb Laternen-Streifen Punkt für Punkt nach Fresnel im Shader (negative halbe Breite), CPU-Faktor entfernt.
- Läuft: queue6 (TEXIT C1RN N1 N2N -> v6) -> queue7 (glow-Sonde, TEXIT+C1RN -> v7, dann gates …)
- ALT: queue5 (v5: … N1_deck, N2N_deck, tabelle) -> queue6 (gates import+check_scripts, TEXIT + C1RN -> v6)
  -> queue7 (gates run_tests sight path render_checks modern_check; warm; bench head/base; stage head/base; clips);
  Protokolle: shots/v5|v6/queue.log, queue7.log, gates/summary.txt. golden_check GANZ ZUM SCHLUSS (einmal).
- Danach: .uid committen, gates.sh run_tests sight path render_checks golden_check modern_check; Bilder ansehen;
  modern_make; Clips (sh/…: ab_clip, CLIP_S=20), warm.sh, bench.sh (head low/medium/high/deck, base medium),
  stage.sh head + base.
- sh/queue4.sh läuft im Hintergrund (wartet auf RCPAIR_DONE): KBN (Pylon, Region x500–780 y150–350 mit
  sh/region.py messen, M2ZS1: Arcade 60,1/255), check_weather tabelle, dann v4-Bilder high TEXIT(52.8, 1.0/2.4/3.8)
  C1 DEV S1DAWN S1DUSK S1OVC C1RN + deck N1/N2N (1280x800) -> shots/v4, Protokoll shots/v4/queue.log.

## Nächste Schritte
1. Bilder ansehen, Feinabstimmung; Commit.
2. Prüfungen: tests/race3d/check_light_cap.gd (kopflos, 3 Nachtetappen), render/check_night.gd (N1 Fahrbahn
   0..+15 % gegen Arcade, Spiegelung, Verdeckung nass), render/check_weather.gd (Teilchen je Effekte-Stufe, Gischt,
   Tabelle Wetter × Stunde).
3. Nachtgesetz senkrechte Flächen messen (N1/C1/DEV), Spielerauto nachts, Look-Punkte M2INT Notiz 6.
4. Bilder (N1,N2,C1,DEV,S1 Dämmerung/Abend, bedeckt, Tunnelausfahrt; high + deck), Clips, Warm-up kalt N1/N2.
5. Gates, Bericht deliver/R4/bericht.md.

## Fallstricke
- QA_M2_FERTIG fehlt -> schwere Jobs mit nice -n 19, einzeln. Last 16–18: ein A/B-Paar ≈ 7–8 min.
- Git: Befehle einzeln (keine && Ketten mit git), Commit-Text per Datei.
