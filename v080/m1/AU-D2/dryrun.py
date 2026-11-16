"""Dry run of a race piece: every pattern of every bar, the melodic lines and the extras – no rendering."""
import importlib
import os
import sys

ROOT = sys.argv[1]
MOD = sys.argv[2]
CLS = sys.argv[3] if len(sys.argv) > 3 else ""
sys.path.insert(0, os.path.join(ROOT, "tools", "audio", "music"))
mod = importlib.import_module(MOD)
import race_lib  # noqa: E402
from music_lib import ms  # noqa: E402

problems = []


def check_lines(tag, lines):
    for j, line in enumerate(lines):
        try:
            ev = ms.parse_line(line)
        except Exception as e:  # noqa: BLE001
            problems.append(f"{tag} line {j}: {e}")
            continue
        end = 0.0
        for st, ln, m, opts in ev:
            if st < end - 1e-9:
                problems.append(f"{tag} line {j}: overlap at step {st}")
            end = st + ln
            if not (40 <= m <= 96):
                problems.append(f"{tag} line {j}: note {m} out of range")
        if end > 16 + 1e-9 and j < len(lines) - 1:
            problems.append(f"{tag} line {j}: {end} steps (> 16)")


def walk(comp, tl, name):
    for b in tl.bars:
        for fn in ("drum_bar", "bass_bar", "pad_bar", "arp_bar", "brass_bar", "fx_bar"):
            try:
                ev = getattr(comp, fn)(b)
            except Exception as e:  # noqa: BLE001
                problems.append(f"{name} {fn} {b.pid}/{b.kind}/{b.j}: {e!r}")
                continue
            for e in ev:
                if isinstance(e[0], (int, float)) and not (0 <= e[0] < 16):
                    problems.append(f"{name} {fn} {b.pid}/{b.j}: step {e[0]}")
        for take in range(4):
            try:
                for e in comp.gtr_bar(b, take):
                    ch = e[5] if len(e) > 5 else b.chord
                    comp.CH[ch]
            except Exception as e:  # noqa: BLE001
                problems.append(f"{name} gtr {b.pid}/{b.j}: {e!r}")
        try:
            comp.CH[b.chord]
        except Exception as e:  # noqa: BLE001
            problems.append(f"{name} chord {b.chord}: {e!r}")
    for row in comp.LEADS:
        check_lines(f"{name} lead {row[0]}+{row[1]}", row[2])
        if not tl.phrase_start(row[0]):
            problems.append(f"{name} lead phrase {row[0]} not in timeline")
    for row in comp.GUITAR:
        check_lines(f"{name} gtr {row[0]}", [ln for ln in row[2]])
    for row in comp.BELLS:
        check_lines(f"{name} bells {row[0]}", row[2])


if CLS:
    pc = getattr(mod, CLS)()
    walk(pc, pc.tl, MOD)
    host = pc
    print(pc.info())
else:
    host = race_lib.ExtrasHost(mod.PIECE, mod.TITLE, mod.GENERATOR, "x", mod.KEY, mod.CH, mod.specs)
ex = race_lib.Extras(host)
tl = ex.timeline()
walk(ex, tl, "extras")
for c in ex.clips(tl):
    print("clip", c[0], c[1], "frames", c[4], c[5], "s", round(c[5] / 44100, 2))
print("PROBLEMS", len(problems))
for p in problems[:60]:
    print(" ", p)
