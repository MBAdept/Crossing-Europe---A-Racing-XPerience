# Notizen AS1-KRITIK (Arbeitsstand, nicht der Bericht)

## Spielerautos (Batch p)
- 9 m Spielkamera vs Sprite: Lage und Größe deckungsgleich (Sprite-Platzierung 640/592.6, Zelle/1.65). -> deliver/01.
- Farbe: Kompakt Zitronengelb statt Bernstein (#f0b30a): Übersteuerung, Rotkanal clippt, Farbton kippt. Limousine
  greller. Gegenlicht-Bild (Sonne von vorn) näher am Sprite -> Sonnenanteil (sRGB addiert) übersteuert. Renderer/Licht.
- Glas: Heckscheibe fast klar, Innenraum gut sichtbar; Sprite dunkel spiegelnd. Geschmack; Spiegelung schwach.
- Blinker hinten: 2 dünne Lichtleiter-Streifen + Endstück; bei 9 m 1 px, im Rot untergehend (Bernstein-Pixel 45->80
  Limousine Tag). Spieler-Blinker im Spiel nie an -> niedrig.
- Rücklicht nachts: nur Lichtleiter-Streifen hell, Körper (Kanal 2) 35 % -> dunkler/dünner als Sprite-Schicht "tail"
  (ganze Leuchte). Rote Pixel linke Leuchte 158 (Rück) vs 361 (Brems).
- Kompakt: schwarzer Keil über beiden Rückleuchten (Ende der schwarzen Heckblende als flaches Blatt über der Schulter,
  Ton: steht ab) – bei 9 m 6x3 px sichtbar, Sprite hat ihn nicht. out/v_notch*.png
- Kompakt: Türfugen gestrichelt (Unterabtastung/z-fighting?) in Nahansicht.
- Stoßfänger-Enden: senkrechte flache Kappe, "aufgeklebter Kasten" (Rad-Nahansicht Limousine).
- Limousine: Schattierungsnaht senkrecht im hinteren Seitenteil (x≈680 in limousine_lod0_wheel).
- Kompakt Front: Facetten an Stoßfängerecken unter Scheinwerfer.
- Diffusor-Finnen hängen als dünne Stäbe unter dem Stoßfänger.
- Scheinwerfer: heller Streifen hinter klarer Scheibe, wirkt wie Aufkleber.
- Normalen: magenta (Normal gegen Wicklung) <= 38 px je Ansicht, 255 px Rad-Nahansicht -> sauber.
- check (cull_disabled): großflächig rot an Dach/C-Säule = Innenverkleidung deckungsgleich mit Außenhaut (Rückseiten);
  unter cull_back unsichtbar -> harmlos (prüfen per Netzanalyse).
- Dritte Bremsleuchte Limousine: Lichtanker ohne "dir" (Vertrag A-4 verlangt dir).

## Verkehr (Batch t)
- Sprite-Vergleich ortho (deliver/05, 06): Silhouetten passen; Heck flacher/kastiger als Sprite; Lampen neu gestaltet
  (rot oben + bernstein unten, flach, schwarze Umrandung) – Sprite: schmale dunkle Leuchten mit weißem Rückfahrfeld.
- Unbeleuchtete Lampen bei Tag hell/gesättigt (lamp_off 0.5): dritte Bremsleuchte als roter Balken auf der Scheibe,
  Bernsteinfelder wirken "an". Tag-Kontrast Bremse an/aus nur x1.5-2.0 (gemessen, Pixel die sich ändern).
- Glas lod0: dunkles Navy ohne sichtbare Spiegelung -> wirkt gemalt. Felgen hellsilber (Sprite anthrazit).
- Farben: Rot rosa/grell, Grün minzig (Himmel + Übersteuerung).
- LOD-Pop gemessen: 40 m lod0->lod1 6-11 % der ~1000 Autopixel >24 Stufen (Kennzeichen-Zeichen weg -> heller,
  Spiegel); 120 m lod1->lod2 24-38 % der ~100 Pixel (Kennzeichen verschwindet, Glas-Kappe). out/v_lodpop.png
- lod2: Kabine als dunkle Kappe inkl. Säulen; Radläufe dreieckig, Räder sechseckig (bei >120 m ok).
- Kein Kofferraumdeckel-Spalt am Heck (glatter Block).
## Netzanalyse (out/mesh_analysis.txt)
- Wicklung sauber (0-3 Dreiecke je Netz). Rücken-an-Rücken-Paare Spieler lod0 6844/8178 (Innenverkleidung
  deckungsgleich mit Außenhaut), Duplikate (gleiche Lage+Richtung) 91-114 Spieler lod0, 133-190 show.
- Räder: Rollachse mittig (0.0 mm), Unrundheit 4 mm (Polygon).
- Freigang: Kompakt Vorderrad: Stoßfänger (Lack) 52 mm im Reifenvolumen bei 0° (frei ab 15°) -> sichtbar
  (kompakt_lod0_wheelf). Limousine Hinterrad: Schweller-Ende 77 mm im Reifen (innen, verdeckt).
- Bremsscheibe wirkt wie polierte Kugel (glatte Normalen).
## Schattenwerfer (caster-Modus: rot = Werfer außerhalb der sichtbaren Haut)
- Lkw: 446-1838 px rot (Fahrerhaus unten/Radlauf, Aufliegerunterkante, Heck zwischen Leuchtenträgern).
- Limousine: im Kühlergrill (Vertiefung tiefer als 12 mm). Andere: Kantenpixel.
## Lkw (Batch k)
- Weiß übersteuert: Heck und Seiten reines 255-Weiß ohne Form (Tag). Kontur-Markierung nachts dunkel (Kanal 8 x
  Rücklicht x 0.45) – Arcade: leuchtend rot. Fahrerhaus kastig, kein Innenraum, Spiegel als Stäbe.
