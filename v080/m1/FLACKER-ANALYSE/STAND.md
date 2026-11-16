# STAND FLACKER-ANALYSE

Rolle: read-only Code-/Shader-/Asset-Analyse (keine Commits, kein Branch, keine Sicherungskopie).
Builds: ZS1 = 39849f0263921f798da4326b83dff30d83a947d2, M2 = 6e484056ec87e2fa614061000a362feb2b5a6db8
Lesen per `git show <commit>:<path>` in /home/user/crossing-europe---a-racing-xperience (kein Checkout).
Parallel laeuft FLACKER-NACHSTELLEN (Reproduktion, Worktree wf_17007edf-ec9-1 vermutlich) - NICHT anfassen.

## Erledigt
- Vertrag §2, §3, §4 (Teile), §5, §6 W0-W2, §8, §11 komplett gelesen.
- Quellen beider Builds extrahiert (git archive): m1/FLACKER-ANALYSE/src/{zs1,m2} (extract.sh)
- Godot-Binary-Strings: m1/FLACKER-ANALYSE/godot_strings.txt (GLES3: `uniform highp uint instance_offset;`)
- Gelesen: layers/vehicles.gd (ZS1), vpbr/glass.gdshader, model_factory.gd, modern_materials.gd, vehicle_pose3d.gd,
  props.gd commit/_mmi, check_instance_budget.gd, config graphics levels, env rig shadow splits.

## Befunde bisher (Kurz)
- _set_level() SETZT car.fade/sun/la/lb zurueck (Z.1318-1323) -> Lead-These "Cache nicht zurueckgesetzt" widerlegt (ZS1).
- LOD-Band Mittel 38-42 m Kamera->Wagenmitte (lod_index, Hysterese 5 %); lod0<->lod1 ohne Ueberblendung.
- Schattenkaskaden: Mittel 2 Splits, split_1 0.3*120 = 36 m; Hoch 4 Splits 0.08/0.2/0.45*200 = 16/40/90 m (blend);
  deck/Niedrig 0.3*80 = 24 m. Kaskadengrenze Hoch genau 40 m!
- INSTANZ-PUFFER: ZS1 hat vpbr-Requisiten MIT Instanz-Uniforms (Eiche, Birke(+_b), Laterne, Hof, Scheune, Windrad,
  Muehle, Zoll, Tankstelle) -> jeder MultiMesh-Knoten je Stueck/Stufe/Spiegel/Werfer 16 Plaetze. M2INT fand Ueberlauf
  auf Waldetappen (T1 5, T4 2, DO-F km121 55 Ablehnungen) und fuehrte VPBR_STATIC ein (nicht in ZS1!).
  Abgelehnte Instanz: offset -1 -> uint 0xFFFFFFFF -> Shader liest Slot idx-1 (globale ce_*), paint (idx0) OOB.
- Weisse PKW in ZS1: hatch_white, wagon_white (Modelle), suv_white, van_white (Sprite-Ersatz). M2: + suv, van, sports Modelle.

- Scratch-Checkout ZS1 (git archive, KEIN git): m1/FLACKER-ANALYSE/co_zs1 (+ .godot kopiert, importiert);
  M2-Modelle nach co_zs1/flk_m2models (.gdignore). Eigene Skripte dort: flk_dump_meshes.gd, flk_count.gd,
  flk_refuse.gd, flk_routes.gd.
- GEMESSEN Netze (meshes_zs1.json, meshes_m2.json, summ_meshes.py): Lackcodes nur 0.000/1.000 (Pkw), Lkw 0.251/0.502;
  0 gemischte Dreiecke; lod0/lod1/lod2 tragen alle Code 0 auf der Karosserie -> keine Stufe "ohne Lack".
- GEMESSEN llvmpipe (flk_refuse.gd, refuse.png): abgelehnte Instanz: Index 0 liest 0 (OOB), Index k liest globalen
  Slot k-1. 300 Quads, 4 Globals -> 45 abgelehnt (255 passen); abgelehnt wurden die ZUERST angelegten (Quad 0..44).
- Rennen: erfurt_kassel nur in Dresden-Dortmund (Erfurt->Kassel); Kassel->Erfurt nur als Einzeletappe.
- GEMESSEN Instanzzahl ZS1 erfurt_kassel "medium": max 214 (ab Kassel, km 136) / 205 (ab Erfurt); Fahrzeuge<=113-117,
  Requisiten <=80, Rest ~39 -> unter 255 (Reserve 41-50).

- GEMESSEN high/deck: max 214/205 (high), 202/196 (deck) -> nirgends ueber 255 (headless, ohne Aufwaermknoten).
- GEMESSEN flk_swap.gd (Xvfb, Kontrollszene, Licht genaehert, Bilder swap/*.png, swaps.log): weisser Kombi/Schraeg-
  heck 40 m: lod0->lod1 5,7-8,8 % Autopixel >24 Stufen, Mittel +-1,5..3,2 (Kennzeichen, Details; Lack bleibt);
  Kaskade1->2 1,6-4,7 %; lod1->lod2 17-26 %; ABGELEHNTE Instanz: 52-63 % >24 Stufen, Mittel 21-72 Stufen,
  Auto schachbrettartig durchsichtig (Dither) -> passt zu "verlor Lackierung". Slot-Annahme fade=ce_wind.x
  stimmt NICHT (Dither blieb mit ce_wind.x=1) - Zuordnung empirisch offen.
- Nutzer-Log: %APPDATA%\crossing-europe-zwischenstand\logs\godot*.log -> "Too many instances" waere Beweis.

- swap 5/5 fertig; Bogen deliver/FLACKER-ANALYSE/stufen_kaskade_ablehnung.png (mk_sheet.py).
- GEMESSEN flk_refuse2.gd: abgelehnte Instanzen erholen sich NICHT (100 Plaetze frei, visible-Toggle, neuer Wert,
  Transform) -> dauerhaft bis Knoten frei.
- Untersteuern bremst bis 3 m/s^2 (vehicle_model.gd:400,425) -> Lenken aendert Abstand -> LOD-Band.
- Spots folgen Strassenrichtung, nicht Lenkung (lights.gd:252-290).

- bericht.md ENTWURF geschrieben (deliver/FLACKER-ANALYSE/bericht.md), Abschnitt 7 = ERGEBNIS_PLATZHALTER.
- flk_slots.gd: abgelehnt -> paint liest 0 (OOB), Index 3-6 lesen ce_snow/ce_time/ce_wind/ce_fog_color (Messung
  durch sRGB-Kette unscharf).

## Jetzt
- NACHFOLGER 4 (2026-11-15 08:03, Nutzer: 'Versuch es noch einmal'): Container neu, Load niedrig. refusal_*.log wieder ohne FLK.
  08:13: flk_refusal_run.gd erweitert um ENGINE-PROBE (FLKH-Zeilen: in einem Bild mit pausierter Rennszene 300 Probe-Quads
  mit instance uniform anlegen, Ablehnungen zaehlen -> echte Reserve inkl. Waisen/Aufwaermknoten). Godot verarbeitet
  schmutzige Instanzen LIFO (SelfList add vorne) -> zuletzt angelegte bekommen zuerst Plaetze (passt zu flk_refuse: Quad 0..44 abgelehnt).
  Laeuft: run_one.sh medium erfurt 0 13 90 4 -> refusal_medium_erfurt_0_13.log
  (alt 08:09: run_one.sh medium erfurt 0 13 60 4 abgebrochen) (Hintergrund, Log refusal_medium_erfurt_0_13.log; Load 21 durch andere).
  flk_refusal_run.gd hat jetzt FLKP-Zwischenzeilen alle 150 Bilder (gilt ab naechstem Lauf).
  Plan: flk_refusal_run.gd pruefen, run_refusal.sh im Hintergrund (eine Konfig nach der anderen), parallel Kernthesen
  stichprobenartig verifizieren, bericht.md Abschnitt 7 fuellen, StructuredOutput.
- NACHFOLGER 3 (2026-11-13 05:27): Container neu gestartet, refusal_*.log ohne FLK-Zeile (abgebrochen). Starte run_refusal.sh neu
  (Hintergrund), pruefe parallel Kernthesen, fuelle bericht.md Abschnitt 7, dann StructuredOutput.
- flk_refusal_run.gd laeuft (run_refusal.sh -> refusal_*.log, 4 Konfigurationen, Load 26 -> langsam).
  Ergebnis in bericht.md Abschnitt 7 eintragen, dann StructuredOutput. (Xvfb, echtes Rennen erfurt_kassel, Logger auf Ablehnung,
  inkl. Ladephase/Aufwaermen) fuer Start ab Erfurt/Kassel medium+high.

## Ergebnisse Nachfolger 4
- GEMESSEN Lauf 1 (medium, ab Erfurt km 0, 13 Uhr, Xvfb, echtes Rennen): Engine-Reserve = 254 - Baumzaehlung EXAKT bei jeder
  Probe (keine Waisen); Reserve f30..f420 (km 0,7..24,7): 145..105, Baum 109..149. Keine echte Ablehnung bis dahin (Endzeile folgt).
- GEMESSEN flk_firstframe.gd (co_zs1): neu angelegte/umgesetzte Instanz zeigt ihre Werte schon im ersten Bild (auch auf
  Plaetzen einer im selben Bild freigegebenen Instanz) -> 'ein Bild mit alten Werten' WIDERLEGT.
- GEMESSEN Lauf 1 FERTIG (lauf1_medium_erfurt_km0_13uhr.log): 715 Bilder bis km 45, 0 echte Ablehnungen, Szene max 162
  (Laden 162, Fahrt 157), Fahrzeug-Ebene Spitze 128 (Budget griff, 9 Freigaben, 48 Bauten), kleinste Engine-Reserve 105.
- Lauf 2 ohne Verkehrs-Vorlauf abgebrochen (km 128 nur 21 Autos). Jetzt LAUF 2b: run_one.sh medium erfurt 124 17 60 4 1
  (--flk-warm=1 -> setup.traffic_warmup) -> refusal_medium_erfurt_124_17_w1.log. Danach Lauf 3: high kassel 124 17 60 4 1.
- GEPRUEFT: keine Netzdatei wird von Fahrzeug- und Nicht-Fahrzeugmodell geteilt (shared_mesh.py) -> kein Materialwechsel
  am geteilten Netz (M2 class_for/VPBR_STATIC) moeglich.
- F5-Fade bei 40 m ausgeschlossen (Sicht 900 m x Wetter x Nacht; Tunnel 0,97).

- 08:50 bericht.md NEU geschrieben (deliver/), Platzhalter: <MINRESERVE> (2x), <LAUF2B>, <LAUF3>, <NPROBEN> in Abschnitt 1/4/7.
  Rangfolge: M2 Stufenwechsel Rang 1 (Nutzer schrieb selbst 'Grafikflackern' und "verlor" in Anfuehrungszeichen),
  M1 Ablehnung Rang 2 (nicht nachgestellt), M3 Kaskade Rang 3.

- 08:44 Lauf 2b (erfurt km 124) abgebrochen: kurzer Lauf baut die Fahrzeug-Ebene nicht auf (veh_inst 26 statt ~113 wie
  headless nach langer Fahrt) -> lauf2_abgebrochen_km124.log. Engine=Baum bestaetigt; headless max 214 bleibt Massstab.
  JETZT Lauf 2c: run_one.sh medium kassel 100 17 90 8 1 20 -> refusal_medium_kassel_100_17_w1.log (~15-25 min).
  Danach: Platzhalter im bericht.md fuellen, Scratch aufraeumen (co_zs1 507 MB, src, mesa, xdg, godot_strings;
  flk_*.gd vorher nach skripte/ kopieren), StructuredOutput.

- GEMESSEN Lauf 2c FERTIG (lauf2_medium_kassel_km100_17uhr.log): ab Kassel km 100-136,2, 17 Uhr, vorgewaermt, 8fach:
  372 Bilder, 0 Ablehnungen, Szene max 206 bei km 136,2, kleinste Engine-Reserve 48, Fahrzeug-Ebene 127.
  Jetzt: Platzhalter fuellen, aufraeumen, StructuredOutput.

- 08:58 Bericht fertig (Platzhalter gefuellt). Scratch aufgeraeumt: co_zs1, src, mesa, xdg, godot_strings GELOESCHT;
  Skripte in skripte/. Nur noch StructuredOutput offen.

## Als naechstes
- Netze lod0/1/2 per Godot dumpen (Lackcodes, Flaechen), Rennen/Richtung erfurt_kassel aus data/network.json
- bericht.md nach deliver/FLACKER-ANALYSE/

## Fallen
- Bash lehnt Heredocs teils ab -> Skripte in Scratch schreiben.

## Scratch
- /tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FLACKER-ANALYSE/
