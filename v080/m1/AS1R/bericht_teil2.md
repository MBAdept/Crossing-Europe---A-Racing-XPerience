## 3. Befunde der Kritik: geprüft, Ursache, Behebung

Jede Zeile wurde vor der Änderung am Netz oder im Bild nachgeprüft (Netzabzug `bin/dump.gd` + `bin/ana.py`,
`bin/probe.py`, Blender-Objektsuche `bin/objs_near.py`, Ton- und Werfer-Ansichten des Kontaktbogens).

| Nr. | Befund (Kritik) | geprüft | tatsächliche Ursache | Behebung | Ergebnis (gemessen) |
|---|---|---|---|---|---|
| A2 | Rücklicht nachts nur Lichtleiter | bestätigt: Kanal 2 Gewicht 0,50 (Netzabzug) | `cardetail._LAMP3D_TAIL["tail"] = "tail_brake:0.5"` | Gewicht 1,0 | ganze Leuchte glimmt (Bild 01, 02); Summe Bremse/Rücklicht linear ≈ 4,5 (Limousine, aus Flächen × Gewicht × Pegel gerechnet) |
| A3 | Kompakt: schwarzer Keil über den Rückleuchten = Ende der Heckblende | **Ursache anders**: im Tonbild ein waagrechtes Blatt; Blender-Suche: die **Hutablage** (Kasten über die volle Kabinenbreite) stand mit ihrer hinteren Ecke aus der gerundeten Schulter; die Heckblende hing zusätzlich 5 mm über der Leuchtenmulde | Hutablage folgt der Außenhaut (`interior3d._shelf`, `outer_z`); Heckblende über Mulden weggeschnitten; Mulden-Splitter (Leuchte streift die Kabine) bekommen keine Mulde mehr | Tonbild ohne Blatt (Bild 03) |
| A4 | Stoßfänger 52 mm im Vorderreifen (Kompakt); Radlaufschale/Schweller im Reifen (Limousine) | Kompakt bestätigt, Ursache: `curves.stations` setzt die Stationen der Endrundung (r_plan + 5 cm = 55 cm) auch jenseits des 46 cm kurzen Stoßfängers – der Loft lief 9 cm in den Radlauf. Limousine: **Ursache anders** – es war der Boden der Innenraumwanne (`#17181a`), nicht Schale oder Schweller | Hook `bumper_clamp`; Wanne und Armaturenbrett mit Abstand zu den Rädern, auch bei 25° Lenkeinschlag | 0 Karosserie-Ecken im Reifenvolumen bei −25…+25° (Netzanalyse, Abschnitt 5) |
| A5 | Stoßfänger-Enden als flache Kappen | bestätigt | Loft endet senkrecht am Radlauf | Hook `bumper_end_r` 5 cm (Spieler und Verkehr `lod0`) | Bild 02, 05 |
| A6 | Bremsscheibe wie polierte Kugel; Limousinenfelgen hellsilber | bestätigt | gedrehter Kasten glatt schattiert; Felge Metall 0,55 hell | harte Kanten 30°, Gusseisen matt; Felgenfarbe wie im Sprite (`#6a6e74`) | Bild 02 |
| A7 | Flimmern von Kennzeichen und Fugen | übernommen (Bewegungsmessung nicht wiederholt) | dünne Zeichen auf Weiß, Fugen 7 mm | Kennzeichen `#d3d4d0`, Zeichen ×1,5 kräftiger, Fugen 8 mm | nicht neu gemessen |
| A10 | Werfer vor Mulden; Anker ohne `dir` | bestätigt (30 mm vor dem Grillgrund) | Hülle gegen die Haut **vor** den Mulden eingezogen; geschlossener Kasten | Hülle gegen die Haut mit Mulden; Lampe als nach hinten blickende Fläche; Prüferregel | Werfer 12,0 mm innen; alle Fahrzeuganker mit `dir` |
| A11 | Innenraum Kompakt 6 268 > 6 000 | bestätigt | Verkleidung = volle Kabine (4 112 Dreiecke) | grober Verkleidungs-Loft, Export-Wächter | Kompakt 3 658, Limousine 3 560 |
| B1 | unbeleuchtete Lampen wirken an | bestätigt; Hauptursache `lamp_off` 0,5 im Shader (R3) | dritte Bremsleuchte: halbe Leuchtfarbe = heller Balken | dunklere Leuchtfarbe der dritten Bremsleuchte (Hook `chmsl_lamp`) | unbeleuchtet (92, 11, 6) statt (128, 18, 10) – gerechnet |
| B3 | Stufensprung 40/120 m | bestätigt | Kennzeichen weiß bzw. weg, Spiegel lackfarben, `lod2`-Heck ohne dunklen Abschluss, grobe Kabine | Kennzeichen grau in allen Stufen und in `lod2` behalten; Spiegelglas in allen Stufen; dunkler Heckabschluss in `lod2` (nicht Schrägheck) | 40 m 6,6–9,8 %, 120 m 22–34 % (Bild 07) |
| B4 | Glas wirkt gemalt | bestätigt | dunkles Navy, Rauheit 0,03, kein Metall | `#2a343e`, Rauheit 0,02, Metall 0,25 in allen Stufen | Bild 05 |
| B5 | Felgen hellweiß | bestätigt | Designfarbe `#b8bcc2` | `#5a5d62`, Metall 0,6, Rauheit 0,35 in allen Stufen | Bild 05 |
| B6/B7 | glattes Heck, Kastenstoßfänger, schwebender Auspuffring | bestätigt | – | Kofferraum-/Heckklappenfugen, Emblem, runde Stoßfänger-Enden, Auspuff als dunkles Rohr | Bild 05 |
| C1 | Kontur nachts dunkel | bestätigt; Gewicht ist 1,0 (nicht 0,79): der Faktor `plate_energy` 0,45 macht sie dunkel | Kanal 8 | Kanal 14 (rückstrahlend über `ce_night`), Gewicht 0,8 | Bild 08 |
| C2 | Weiß ohne Form | bestätigt (Belichtung des Kontaktbogens) | `#ececea` | `#d8d8d6` | im Kontaktbogen-Licht weiter übersteuert (R1/R3) |
| C3 | Werfer ragt aus der Hülle | bestätigt | Kasten unter dem Fahrerhaus, Platte unter dem Auflieger | Werfer aus den wirklichen Teilen | Bild 09 |
