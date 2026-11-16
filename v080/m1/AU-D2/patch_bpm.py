import os
import sys
d = sys.argv[1]
edits = {
    "nachtfahrt.py": [
        ("C minor, 112 bpm (1 bar = 15/7 s)", "C minor, 108 bpm (1 bar = 20/9 s; a sixteenth = 6125 frames exactly)"),
        ("breakdown (bells over the arpeggio), guitar solo, lift, hook with everything, turnaround\n"
         "                       (half-time) – loop 80 bars = 171.43 s (7,560,000 frames)",
         "breakdown (bells over the arpeggio), guitar solo, lift, hook with everything, turnaround\n"
         "                       (half-time) – loop 80 bars = 177.78 s (7,840,000 frames)"),
        ("Where „Linke Spur“\n(D minor, 132 bpm)", "Where „Linke Spur“\n(D minor, 132 bpm)"),
        ("    BPM = 112.0\n", "    BPM = 108.0          # a sixteenth is a whole number of frames: the two passes over the loop start are\n"
                             "    # identical (at 112 bpm a sixteenth was 5906.25 frames, onsets on half frames rounded differently)\n"),
    ],
    "rueckenwind.py": [
        ("A major, 144 bpm (1 bar = 5/3 s)", "A major, 147 bpm (1 bar = 80/49 s; a sixteenth = 4500 frames exactly)"),
        ("(D minor, 132 bpm) and „Nachtfahrt“ (C minor, 112 bpm)", "(D minor, 132 bpm) and „Nachtfahrt“ (C minor, 108 bpm)"),
        ("guitar solo, lift, hook with everything, motif in octaves, turnaround – loop 88 bars\n"
         "                       = 146.67 s (6,468,000 frames)",
         "guitar solo, lift, hook with everything, motif in octaves, turnaround – loop 88 bars\n"
         "                       = 143.67 s (6,336,000 frames)"),
        ("    BPM = 144.0\n", "    BPM = 147.0          # a sixteenth is a whole number of frames (see nachtfahrt.py)\n"),
    ],
    "zwischenspiel.py": [
        ("E minor like the title theme, 96 bpm (1 bar = 2.5 s)", "E minor like the title theme, 98 bpm (1 bar = 120/49 s, a sixteenth 6750 frames)"),
        ("Form (1 bar = 2.5 s):", "Form:"),
        ("  loop 32 bars = 80.0 s (3,528,000 frames);", "  loop 32 bars = 78.37 s (3,456,000 frames);"),
        ("BPM = 96.0\n", "BPM = 98.0               # a sixteenth is a whole number of frames: the loop seam is exact\n"),
        ("Schleife A B A' B' T (32 Takte = 80 s)", "Schleife A B A' B' T (32 Takte = 78,4 s)"),
    ],
}
for name, reps in edits.items():
    p = os.path.join(d, name)
    s = open(p, encoding="utf-8").read()
    for a, b in reps:
        if a not in s:
            print("MISSING in", name, ":", a[:60])
            continue
        s = s.replace(a, b, 1)
    open(p, "w", encoding="utf-8").write(s)
print("done")
