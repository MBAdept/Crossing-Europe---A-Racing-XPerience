# Entwurf für StructuredOutput (R4)

## notes_for_next (≤10)
1. R5: Tunnel-Builder ruft in update() `env.set_zone("tunnel", amount)` (duck-typed über renderer.get("env"), has_method) –
   ab dem ersten Aufruf gilt nur noch der gesetzte Wert; die Belichtungsrampe an der Ausfahrt braucht builder "tunnel"
   und die Röhre als Verdecker des Glare-Vierecks (tiefengetestet; steht ≥ 1,5 m vor dem Spielerauto).
2. R5: Tunnellampen bekommen eine Pool-Reichweite (`range` in add_lamps), damit sie in den Punktlicht-Pool kommen;
   Brücken über Wasser `set_zone("bridge", 0..1)` (Wind +50 %).
3. R7 (mit R4, A-…): Zeitfaktor in billboard.gdshader, der das Relief der Impostoren in Dämmerung/Nacht abschwächt –
   nicht gemacht.
4. Modellpakete: Fern-Konstanten (TRAFFIC_GLASS_FAR, FAR_PLATE, GLASS_FAR, CHECK_MEAN_EXP) gegen den geänderten
   VEHICLE_LOOK (hemi_side 0,72 / hemi_down 0,5 für vpbr und glass) nachmessen.
5. Look offen: Dämmerung – Klarlack spiegelt den lila Himmel, blaue Limousine blasser als Sprite; GT silber im Regen
   bei Tag +13 % (Mittel) / +34 % (p75) heller und flacher als Sprite; nachts Lacke blasser (Schimmer in Himmelsfarbe).
6. PERF/QA: Laufzeiten der neuen Render-Prüfungen bei Last 20: check_night ~550 s, check_weather (ohne Tabelle) ~?,
   check_weather_tabelle ~620 s, _schnee ~310 s.
7. Vertragsfragen an Leitung: GPUParticles3D → zustandslose Teilchen; Effekte-Tabelle spray/wet_reflections.
8. props.gd unverändert (Entscheidung 6: R5/R6-Einzeiler beim Merge behalten); add_lamps()-API unverändert.
