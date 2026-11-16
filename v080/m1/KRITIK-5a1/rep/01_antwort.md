## 1. Die Antwort für den Nutzer

**Frage: Sind die Stadthäuser sichtbar feiner als die Arcade-Bilder und gut genug, um stundenlang durch die Städte zu
fahren?**

- **Feiner: ja – bei neun von elf Modellen deutlich, bei Büroturm und Kran gleich.** Von 10 bis 100 m haben die Häuser
  echte Tiefe: Fenster in Laibungen mit Rahmen, Sprossen und Sohlbänken, Fachwerk als Hölzer vor der Ausfachung,
  Vorkragungen mit Balkenköpfen, Gesimse, Pilaster, Fensterverdachungen, Quaderecken, Balkone mit ausgeschnittenen
  Gittern und Schlagschatten, Rundbogentüren mit Flügeln, Schaufenster mit Regalen und Waren hinter dem Glas (Bilder
  10–12, 20). Im Rennen in Hamburg, Nürnberg und Hannover sind sie schärfer und plastischer als Arcade, dessen Sprites
  aus der Nähe verschwimmen (Bilder 02–04). Umriss, Geschosse, Dächer, Farben und Fensterraster decken sich mit dem
  Sprite (IoU 0,987–0,999, Kran 0,922, gemessen); Budgets, Zeichenaufrufe und Bytes sind eingehalten (größtes Modell
  9 865 Dreiecke, 2 Aufrufe je Stufe, Archiv 0,79 MB Netze + 5,25 MB Texturen, gemessen). {{NACHT_SATZ}}
- **Stundenlang: noch nicht ohne Nacharbeit.** Was in den Innenstädten in Augenhöhe am meisten vorbeizieht, sind die
  Straßenflanken – und die sind bei Fachwerkzeile, Turmhaus und Barock im Erdgeschoss, bei der Giebelzeile über die
  ganze Höhe **blind** (K2, Bild 30): Arcade zeigt im selben Moment Fassaden mit Türen und Fenstern. Dazu flimmern die
  Fachwerk-Hölzer bei 40–60 m 3–14× so stark wie das Sprite (K6, 1,1–1,4 % gegen 0,1 %), der Stufenwechsel bei 60 m
  tauscht beim Fachwerk ein Drittel der Pixel (K5, nachts +9 % Helligkeit), Geländer verschwinden ab ~75 m (K7), und der
  Turm-Erker hat gemalte Fenster auf einer weißen Plastik-Konsole (K4).
- **Was nicht an den Modellen liegt, aber das Stadtbild im Rennen am stärksten verschlechtert:** In Kurven nimmt der
  Requisiten-Bauer ganze Häuser weg – in München fehlt die linke Straßenseite (K1, Bild 01; FIX-M2 B-01 ist offen).
  Hamburgs Vororte sind weiß statt rosa, bis R7 die Tönung auf Modelle legt (K3, Bild 05). Sonnige helle Putzfassaden
  sind mittags 8–51 % heller als in Arcade (K8, Licht).
- **Empfehlung:** Die elf Modelle können in den nächsten Testbuild – sie sind besser als die Arcade-Bilder, die sie
  ersetzen, und nichts ist kaputt. Vor dem Testbuild sollte die Leitung K1 entscheiden (sonst sieht der Nutzer
  halbleere Straßen). Nacharbeit AS5a-N in dieser Reihenfolge: K2 (Flankenöffnungen über `close3d`), K6 und K5
  (Hölzer, lod1), K4, K7, K10. R7: Tönung und Überblenden; R4: Sonne gegen Arcade {{R4_ZUSATZ}}.

| Modell (Platzierungen K–N) | gegen das Sprite | im Rennen bereit | was es trägt | was es kostet |
|---|---|---|---|---|
| Einfamilienhaus (282) | **feiner** | ja (Tönung fehlt, K3) | Rahmen + Sprossen, Rinnen, Fallrohre, Garagentor, Wandlampe nachts, 60 px/m zur Straße | Gartenkugeln, lod1 fast so teuer wie lod0 (K10) |
| Fachwerkzeile (99) | **feiner** | ja, mit K2/K5/K6 | Hölzer als Glieder, Vorkragungen, Blumenkästen, Rundbogentür | blinder Sandsteinsockel zur Straße, Stufenwechsel 32 %, Flimmern 1,1–1,4 % |
| Fachwerk mit Turm (95) | **feiner** | ja, mit K2/K4 | Hölzer, Turm mit Schieferhelm, Torbogen mit Holzflügeln | gemalte Erkerfenster, weiße Konsole, blinder Ziegelsockel |
| Mietshaus (77) | **feiner** | ja | Balkone mit Platte, Gitter und Schlagschatten, Treppenhausfenster, Gauben | Geländer ab ~75 m weg (K7) |
| Gründerzeithaus (72) | **feiner** | ja | Quaderecke, Verdachungen, Erker, Schaufenster mit Auslage auch zur Straße | sonnig sehr hell (K8), Geländer (K7) |
| Giebelzeile (54) | **feiner** (Front) | ja, mit K2 | Treppen-, Volutengiebel als Geometrie, Rundbogenfenster, Ziegelverband | Flanke 16 × 17 m ohne Öffnung, nachts dunkle Platte; flimmert in lod1 |
| Barock (32) | **feiner** | ja, mit K2 | Pilaster, Gesimse, Fensterverdachungen, Volutengiebel | blinder Rustika-Sockel zur Straße |
| Speicher (10) | **feiner** | ja | Granitsockel, Gesimsbänder, Ladeluken, Eckturm | – |
| Büroturm (7) | gleich | ja | Vorhangfassade mit Pfosten, Flugbefeuerung | Foyer nachts weiße Tafeln (K10) |
| Kontor (4) | **feiner** | ja | Pfeilerfassade, Staffelgeschosse, Schaufenster mit Auslage | Stufenwechsel 25 %, oben 24 px/m bei Maßstab 1,2 |
| Kran (3) | gleich | ja | Gitterausleger, Kabine, Seil, Rotlicht | flache rote Kästen (nie nah) |
