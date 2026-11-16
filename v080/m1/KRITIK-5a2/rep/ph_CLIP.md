(1) **Rennclip Amsterdam** (`tools/ab_clip.sh`, Bremen – Amsterdam ab km 357,2, `--autopilot-target=50`, Mittel, 12 Uhr,
6 s, 60 fps, je Seite 1280×720; Bilder 40–42; beide Läufe Exit 0, Modern 311 s): Grachtenhäuser beidseits, Flanken mit
Fenstern, ferne Giebel scharf – in Bewegung klar feiner als Arcade. Zeitliche Unruhe der fernen Fassaden in der Bildmitte
(`py/rough2.py`, mittlere |2. Zeitableitung| der Helligkeit, H.264): Modern 10,8 gegen Arcade 5,7, „kippende“ Pixel
11,4 gegen 6,6 % (gemessen; Inhalt nicht identisch, grob). In den Folgebildern (42) bleiben die Fensterraster stabil;
dünne weiße Gesimslinien kippen von Bild zu Bild. (2) **Prüfstraße Paris** (`k5_scene --mode=drive`, Haussmann und
Eckhaus beidseits alle 26 m, 50 km/h, Mittel, 2,5 s, unkomprimiert; Bild 43/44): ferne Zeilen 2,0–2,1× so unruhig wie
die Arcade-Platzhalter (8,5 / 14,9 gegen 4,1 / 7,5; kippende Pixel 11,4 / 17,5 gegen 4,1 / 8,5 %), nahe Fassaden
1,3–1,7×. Dafür ist das Modell scharf und perspektivisch richtig, die Platzhalter sind unscharfe, zur Kamera gedrehte
Tafeln (Bild 44). Die zwei Stufenwechsel bei 60 m im Film gehen im Bewegungsrauschen unter (`py/swappop.py`: 10,8 % neu
geänderte Pixel im Wechselbild gegen 10,4 % davor/danach). Die Wirkung auf einem echten 60-Hz-Bildschirm ist gefolgert.
