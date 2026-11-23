- **Leitentscheid 1 gegen 3 (QR7c-01, Vertragsfrage):** Stadthäuser außer Fachwerk/Paris behalten lod0 bis 60 m
  („Mittel“), obwohl lod0 von Grachtenhaus (0,6 / 0,7 % bei 40 / 60 m) und Chalet (0,4 / 0,7 %) mehr als 2 × ihr Sprite
  (0,1–0,2 %) flimmert (R7c gemessen). Ich habe dem Look Vorrang gegeben, wie QA-R7c empfiehlt (lod1 des Speichers ist
  Sprite-Niveau); die Leitung sollte das bestätigen oder die Asset-Pakete die Kassetten in lod1 backen lassen.
- **A-16 Zeitblende (QR7c-06):** jetzt ein Mischweg ohne Zustand je Instanz: in Fahrt das Wegband (wie R7c), bei
  stehender Kamera eine echte Zeitblende von 0,4 s über das globale `ce_lod_still` (keine Instanz-Uniform, A-19 bleibt).
  Statt der von QA vorgeschlagenen harten Entscheidung in der **Bandmitte** zieht sich das Band zu seinem **fernen Ende**
  zusammen – so steht beim Stand die feinere Stufe (Countdown-Bild wie die Basis). Neue globale Variable in
  `ModernMaterials.GLOBALS` (Datei im Besitz von R7c; ein Steckplatz des globalen Puffers).
- **A-22 `max_dist_m` in `model.json`:** weiter über `graphics.modern.props.lod0_m` je Modell (Besitz der Asset-Pakete,
  wie bei R7c); der Tag-Ersatz `tag:city` ist gestrichen, die Mechanik je Tag bleibt (Test).
- **Leitentscheid 3, Farb-Bias:** neuer Konfigurationsschlüssel `graphics.modern.props.albedo_bias` (je Modell
  [Stufen, von, bis]) – gemessen gewählt (Abschnitt 2, QR7c-04).
- **QR7c-08:** Anbauten jenseits des eigenen Stücks werden ausgelassen statt dem Nachbarstück übergeben – das Nachbarstück
  sieht die Gegenstände dieses Stücks nicht (`ChunkContext.segs` reicht nur eine Reihe weiter; Kern, nicht meine Datei).
- **A-18 Modern-Goldens:** MODERNGOLDENS
- `check_lod_band`: Grenze des größten Schritts von 35 % auf 15 % des harten Wechsels verschärft (gemessen 8,5 %; der
  gerasterte Schattendurchgang 17 %) – wird ein Haus-Asset umgebaut, ist der Wert neu anzusehen.
