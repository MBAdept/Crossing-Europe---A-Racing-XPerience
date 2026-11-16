## 7. Vertragsfragen und Bedarf bei anderen Paketen

1. **Zwei Zeichenaufrufe je Stufe gegen Geländer, Gartenbäume und Wandleuchten (§4.6.9, §4.6.3).** Ein Stadthaus
   mit Schmiedeeisen braucht `baked_cutout`; weil nur zwei Aufrufe erlaubt sind (`vpbr` + eine gebackene Klasse),
   liegt bei fünf der zwölf Modelle (907 Platzierungen) und bei zwei Modellen der Charge 1 die **ganze Fassade** in der
   Ausschneide-Klasse (`cull_disabled`, `discard`, auch in lod1). Dieselbe Grenze verhindert, dass ein Gartenbaum ein
   AS3-Baum (`leaves`) wird, wie die Qualitätsvorgabe es verlangt. Vorschlag: für Stadthäuser drei Oberflächen
   zulassen (`vpbr` + `baked` + `baked_cutout` oder `leaves`), lod1 immer ohne Ausschneide-Klasse – **oder** ein
   Anbau-Mechanismus im Requisiten-Bauer (R7: Modell nennt in `model.json` Anbauten wie `tree_oak@x,z,h`, der Bauer
   stellt das AS3-Modell dazu). Bitte um Entscheidung der Leitung vor AS5b (dort kommen mediterrane Gärten, Palmen,
   Oliven, Balkone).
2. **Mip-Kette der Ausschneide-Atlanten (§4.6.5, D23; offen seit KRITIK-5a1 K7).** Mit den Import-Mips (Box-Filter)
   ist „Deckung in kleinen Mips erhalten“ nicht erfüllbar: ohne `cut_fill` verschwanden die Geländer (Charge 1), mit
   `cut_fill` schließen sie sich (hier 1,5–4,2-fache Deckung ab Mip 2). Wer darf eine deckungserhaltende Mip-Kette in
   `bake.py`/den Import-Einstellungen bauen (oder Alpha-to-Coverage im Renderer, R7)? Ohne diese Entscheidung bleibt
   jede Ausschneide-Arbeit an Modellen Flickwerk.
3. **„Die Generatoren SIND das Aussehen“ gegen erfundene Flankenöffnungen.** AS5a2 hat – wie AS5aR1 – Fenster und
   Türen an Flanken gesetzt, die im Sprite blind sind und in Wirklichkeit Brandwände wären (Grachten- und Reihenhäuser).
   Für das Spiel ist das richtig (Bild 10/20: die Flanke ist im echten 3D die größte Fläche beim Vorbeifahren), aber
   es weicht vom Wortlaut ab. Die Zustimmung der Leitung, die KRITIK-5a1 erbat, sollte festgeschrieben werden (A-16
   oder ein neuer Punkt), damit AS5b nicht neu fragen muss.
4. **Fernbild (R7).** Die Fassaden aller zwölf Modelle werden zwischen 60 und 250 m 5–10 % heller und verlieren ihre
   dunklen Fenster (5.4) – unabhängig von der Stufe. R7 plant Fernbilder (Impostoren mit dem Relief des Sprite-Rigs,
   A-16). Wenn R7 ab etwa 200 m das Sprite-Bild des Sets zeigt, ist das Problem dort gelöst; dann müsste AS5a-N nur den
   Bereich 100–200 m (dunklere Fenster in den kleinen Mips) behandeln. Bitte R7 diese Grenze nennen lassen.
5. **Überblenden der Stufen (A-16 nur für Bäume).** Stadthäuser wechseln bei 60 m 9–18 % der Pixel, auf „Hoch“ bei
   120 m bis 23 %, nachts +3 bis +5 % Helligkeit. Bitte R7 das Dither-Überblenden auch für `building`/`city` geben.
6. **Nachtlicht der Schaufenster (A-16: „emit_energy 1.6 gegen Arcade abgeglichen“).** Die Wohnfenster sind
   abgeglichen, die Auslagen nicht (AS5a2 gemessen 124 gegen 207, siehe K1). Weil die Formel in `cities3d._display_mat`
   beide Chargen trägt, braucht die Korrektur einen Neu-Export aller 23 Stadthäuser – die Leitung sollte das der
   Nacharbeit AS5a-N zusammen mit K2–K4 geben, damit nur einmal neu gebacken wird.
