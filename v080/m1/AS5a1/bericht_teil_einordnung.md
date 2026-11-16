## Ehrliche Einordnung

**Was der Spieler jetzt sieht** (Bilder dieses Ordners; Wirkung auf einen Menschen gefolgert):

- **An jeder Stadteinfahrt von Kiel bis Nürnberg** stehen statt flacher Arcade-Bilder echte Häuser – Einfamilienhäuser
  der Vororte (282 Platzierungen), Fachwerkzeilen und Turmhäuser in Würzburg und Nürnberg (194), Mietshäuser und
  Gründerzeitblöcke in Hannover, Kassel, Bremen, Dortmund (149), Giebelhäuser, Speicher, Kontor und Kräne in Kiel,
  Hamburg und Bremen (71). Umriss, Geschosse, Dachformen und Fensterraster stimmen mit dem Sprite überein (IoU ≥ 0,987,
  Kran 0,922, gemessen).
- **Aus der Nähe (5–15 m)** haben die Fassaden Tiefe, die das Sprite nicht hat: Fenster in Laibungen mit Rahmen,
  Sprossen, Sohlbank und Scheibe; Fachwerk als Hölzer vor der Ausfachung; Vorkragungen, Gesimse, Pilaster,
  Fensterverdachungen, Erker; Balkone mit Platten und ausgeschnittenen Geländern; Türen mit Flügeln und Stufen,
  Rundbogentüren mit Bogen; Schaufenster mit Auslage (Regale, Kleiderstange, Theke) hinter dem Glas. Ziegel-, Putz-,
  Sandstein- und Dachdeckungsmuster des Generators im Atlas mit Umgebungsverdeckung, ≥ 40 px/m in Erdgeschoss und
  erstem Obergeschoss der Innenstadthäuser (Modellmaß).
- **Nachts** leuchten dieselben Fenster wie in Arcade, warm und unregelmäßig, Schaufenster mit beleuchteter Auslage,
  die Wandlampe des Einfamilienhauses, Rotlicht und Strahler des Krans, die Flugbefeuerung des Büroturms; bei Tag
  leuchtet nichts.
- **Rückseiten** sind geschlossen und gestaltet (Rückgiebel der Fachwerkhäuser, gespiegelte Straßenwand mit denselben
  Fenstern) – in Kurven sieht man keine offenen Kästen.

**Was noch nicht gut ist** (gemessen, wo eine Zahl steht):

1. **Flimmern in Bewegung** liegt über dem des Sprites: Fachwerkzeile 1,1–1,3 % bei 40–60 m (Sprite 0,1 %), Giebelzeile
   1,3 % bei 150 m (Sprite 0,3 %), Turmhaus 0,8–1,0 % (Sprite 0,2–0,6 %); Mietshaus, Gründerzeit und Kontor 0,3–0,8 %.
   Ursache: Kanten echter Geometrie (Hölzer, Laibungen) und kontrastreiche Atlasmuster ohne Vorfilterung; das Sprite
   ist weichgezeichnet. Mit MSAA („Hoch“) weniger (gefolgert, nicht gemessen).
2. **Stufenwechsel bei 60 m** ändert 10–32 % der Pixel (Fachwerkzeile am meisten: echte Hölzer gegen gemaltes
   Fachwerk, Helligkeit +4,6 % am Tag, +8,9 % nachts; Kontor nachts +9,1 %). Silhouette und Fenster bleiben, aber ein
   aufmerksamer Spieler kann das Umschalten der Fachwerkhäuser sehen. Ein weiches Überblenden ist Sache des Renderers
   (R7, LOD-Feinabstimmung).
3. **Geländer** dünnen ab Mip 4 aus (Deckung 0,29 / 0,59 gegen Mip 0) – etwa ab 100 m (gerechnet): die Balkone
   werden dort heller und luftiger als im Sprite. Mip-Stufen mit erhaltener Deckung bräuchte der Import.
4. **Büroturm-Foyer** nachts eine gleichmäßig gedimmte helle Fläche ohne Auslage (7 Platzierungen); **Erkerfenster**
   des Turmhauses sind gemalt (nachts gelbe Felder ohne Sprossen); die **Konsole** unter dem Erker wirkt nachts zu hell;
   **Blumenkästen** der Fachwerkzeile und **Hecken** des Einfamilienhauses aus der Nähe kantig.
5. **Texeldichte im Spiel**: Kontor und Giebelzeile stehen mit Maßstab bis 1,2 – ihr Erdgeschoss hat dann 34–36 px/m
   statt ≥ 40 (gerechnet aus dem gemessenen Modellmaß).
6. Die **Tönung** der Vororte (Einfamilienhaus `#e8b8a4` in Kiel, Hamburg, Bremen, Rostock usw.) zeichnet der Renderer
   für Modelle noch nicht – bis R7 sie als Instanzfarbe aufträgt, sind diese Häuser in Modern weiß statt rosa.

**Was fehlt:** Messungen auf echter Grafikkarte und dem Steam Deck; die zweite Hälfte der Stilfamilien (AS5a2/AS5b);
Bäume der AS3-Modelle in den Gärten (der Gartenbaum des Einfamilienhauses ist der dezimierte Generatorbaum).

**Am schwächsten** (für die Kunstkritik): das Flimmern und der Stufenwechsel der Fachwerkzeile – des zweithäufigsten
Sets – und die Geländer ab 100 m.
