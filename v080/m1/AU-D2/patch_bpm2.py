import os
import sys
d = sys.argv[1]
edits = {
    "nachtfahrt.py": [
        ("C minor, 108 bpm (1 bar = 20/9 s; a sixteenth = 6125 frames exactly)",
         "C minor, 105 bpm (1 bar = 16/7 s; a sixteenth = 6300 frames = 100 x 63 exactly)"),
        ("(half-time) – loop 80 bars = 177.78 s (7,840,000 frames)",
         "(half-time) – loop 80 bars = 182.86 s (8,064,000 frames)"),
        ("    BPM = 108.0          # a sixteenth is a whole number of frames: the two passes over the loop start are\n"
         "    # identical (at 112 bpm a sixteenth was 5906.25 frames, onsets on half frames rounded differently)\n",
         "    BPM = 105.0          # a sixteenth is a whole multiple of 63 frames (race_lib.check_tempo): the two passes\n"
         "    # over the loop start are identical\n"),
    ],
    "rueckenwind.py": [
        ("A major, 147 bpm (1 bar = 80/49 s; a sixteenth = 4500 frames exactly)",
         "A major, 150 bpm (1 bar = 1.6 s; a sixteenth = 4410 frames = 70 x 63 exactly)"),
        ("(D minor, 132 bpm) and „Nachtfahrt“ (C minor, 108 bpm)", "(D minor, 132 bpm) and „Nachtfahrt“ (C minor, 105 bpm)"),
        ("= 143.67 s (6,336,000 frames)", "= 140.8 s (6,209,280 frames)"),
        ("    BPM = 147.0          # a sixteenth is a whole number of frames (see nachtfahrt.py)\n",
         "    BPM = 150.0          # a sixteenth is a whole multiple of 63 frames (race_lib.check_tempo)\n"),
    ],
    "zwischenspiel.py": [
        ("E minor like the title theme, 98 bpm (1 bar = 120/49 s, a sixteenth 6750 frames)",
         "E minor like the title theme, 100 bpm (1 bar = 2.4 s, a sixteenth 6615 frames = 105 x 63)"),
        ("  loop 32 bars = 78.37 s (3,456,000 frames);", "  loop 32 bars = 76.8 s (3,386,880 frames);"),
        ("BPM = 98.0               # a sixteenth is a whole number of frames: the loop seam is exact\n",
         "BPM = 100.0              # a sixteenth is a whole multiple of 63 frames (race_lib.check_tempo): exact seam\n"),
        ("Schleife A B A' B' T (32 Takte = 78,4 s)", "Schleife A B A' B' T (32 Takte = 76,8 s)"),
    ],
}
for name, reps in edits.items():
    p = os.path.join(d, name)
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        if a not in s:
            print("MISSING in", name, ":", a[:70])
            continue
        s = s.replace(a, b, 1)
    open(p, "w", encoding="utf-8").write(s)
print("done")
