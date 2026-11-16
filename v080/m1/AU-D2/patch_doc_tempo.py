import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
reps = [
    ("Das dunkle der drei Rennstücke: c-Moll, 108 bpm (1 Takt = 20/9 s, eine Sechzehntel genau 6125 Frames), eine",
     "Das dunkle der drei Rennstücke: c-Moll, 105 bpm (1 Takt = 16/7 s, eine Sechzehntel genau 6300 Frames), eine"),
    ("`nachtfahrt.ogg`: Einzähler und A1 einmal, dann die Schleife B1 … T, A1 (80 Takte = 177,78 s, 7 840 000 Frames) –",
     "`nachtfahrt.ogg`: Einzähler und A1 einmal, dann die Schleife B1 … T, A1 (80 Takte = 182,86 s, 8 064 000 Frames) –"),
    ("Das helle der drei: A-Dur, 147 bpm (1 Takt = 80/49 s, eine Sechzehntel genau 4500 Frames), aufbrechender",
     "Das helle der drei: A-Dur, 150 bpm (1 Takt = 1,6 s, eine Sechzehntel genau 4410 Frames), aufbrechender"),
    ("`rueckenwind.ogg`: Einzähler und A1 einmal, dann die Schleife B1 … T, A1 (88 Takte = 143,67 s, 6 336 000 Frames).",
     "`rueckenwind.ogg`: Einzähler und A1 einmal, dann die Schleife B1 … T, A1 (88 Takte = 140,8 s, 6 209 280 Frames)."),
    ("Stück gibt): e-Moll wie die Titelmelodie, 98 bpm (1 Takt = 120/49 s, eine Sechzehntel 6750 Frames), im Markenklang,",
     "Stück gibt): e-Moll wie die Titelmelodie, 100 bpm (1 Takt = 2,4 s, eine Sechzehntel 6615 Frames), im Markenklang,"),
    ("`zwischenspiel.ogg`: das Intro (= die letzten zwei Takte der Schleife) einmal, dann 32 Takte = 78,37 s\n(3 456 000 Frames)",
     "`zwischenspiel.ogg`: das Intro (= die letzten zwei Takte der Schleife) einmal, dann 32 Takte = 76,8 s\n(3 386 880 Frames)"),
    ("""12. **Tempo und Abtastraster** (AU-D2): Eine Sechzehntel muss eine ganze Zahl von Frames sein (bpm teilt
    661 500: 98, 105, 108, 126, 135, 140, 147, 150 …). Bei 112 und 144 bpm (5906,25 / 4593,75 Frames) lagen Einsätze
    auf halben Frames und rundeten im ersten und im zweiten Durchgang verschieden – die Fortsetzung wich vom
    Schleifenbeginn um −30 dBFS ab (gemessen; die Lead-Noten ab dem zweiten Ton jedes Takts um einen Frame
    verschoben). Mit 108 / 147 / 98 bpm ist sie exakt. 132 bpm (Linke Spur, 5011,36 Frames) trifft nie genau
    ,5 und ist exakt (−172 dBFS).""",
     """12. **Tempo und Schleife** (AU-D2): Damit die zwei Durchgänge über den Schleifenbeginn gleich sind, braucht ein
    Stück zwei Dinge. (a) Eine Sechzehntel ist eine ganze Zahl von Frames – bei 112 und 144 bpm (5906,25 / 4593,75
    Frames) lagen Einsätze auf halben Frames und rundeten im ersten und im zweiten Durchgang verschieden: die
    Fortsetzung wich vom Schleifenbeginn um −30 dBFS ab (gemessen; die Lead-Noten ab dem zweiten Ton jedes Takts um
    einen Frame verschoben). (b) Die Schleife ist ein Vielfaches von 63 Frames: Der eingefrorene Kompressor
    (`music_synth.compressor_gain`) misst den Pegel in Blöcken zu 63 Frames ab Frame 0 – sonst liegt das Raster in
    beiden Durchgängen anders und die Kompressoren regeln um etwa 0,1 dB verschieden (gemessen bei 108 bpm: −34 dBFS
    über die ganze Schleife). Beides erfüllen 100, 105, 125, 140, 150 bpm für jede Taktzahl (eine Sechzehntel ist ein
    Vielfaches von 63 Frames); `race_lib.check_tempo()` lehnt andere Tempi ab. „Linke Spur“ (132 bpm, Schleife
    7 056 000 = 63 × 112 000 Frames) trifft nie genau einen halben Frame und ist exakt (−172 dBFS)."""),
]
for a, b in reps:
    if a not in s:
        print("MISSING:", a[:70])
        continue
    s = s.replace(a, b, 1)
open(p, "w", encoding="utf-8").write(s)
print("done")
