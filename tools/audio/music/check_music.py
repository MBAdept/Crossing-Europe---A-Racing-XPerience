#!/usr/bin/env python3
"""Musical checks of the Modern music files (contract §6 AU-D1: "remaster = same notes – key and chord-root check
against the original"). Complements tools/audio/qc/audio_qc.py (files, levels, seams): this one listens to the notes.

  python3 tools/audio/music/check_music.py            title remaster against the title theme of v0.5.0, race piece 1
  python3 tools/audio/music/check_music.py --json r.json

Per bar a 12-bin chroma from tonal spectral peaks (the method of tools/audio/music_preview.py; below 130 Hz cut off,
where the four-on-the-floor kick layers put a comb of lines), the best-matching triad and its root:
  title    original (assets/audio/music/title_theme.ogg) and remaster (assets/audio/modern/music/titel_remaster.ogg)
           bar by bar on the timeline of tools/audio/music_synth.py: the pitch-class distribution of each bar (cosine
           of the two chroma vectors, median >= 0.9), the root of the best triad (>= 85 % of the bars equal – triads
           that share two notes, Am / C, flip where a held melody note tips the balance), both against the score
           (music_synth.SECTIONS), and the key before the final chorus (it modulates a whole tone up).
  race     linke_spur.ogg against its own score (linke_spur.PHRASES, count-in, the loop), key D minor; and the ending
           against B♭ – C – d.
Exit code 0 when every check passes. Measured, deterministic.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import music_lib as mlib  # noqa: E402
from music_lib import ms, qc_lib  # noqa: E402

ROOT = mlib.ROOT
ORIGINAL = os.path.join(ROOT, "assets", "audio", "music", "title_theme.ogg")
MUSIC = os.path.join(ROOT, "assets", "audio", "modern", "music")
LOW_CUT_HZ = 130.0


def _read(path: str) -> np.ndarray:
    x, sr = qc_lib.read_audio(path)
    if sr != mlib.SR:
        raise SystemExit(f"{path}: {sr} Hz")
    return x


def _chords(x: np.ndarray, starts: list, bar_s: float) -> tuple[list, np.ndarray]:
    ch = mlib.chroma_bars(x, starts, bar_s, LOW_CUT_HZ)
    return [mlib.best_triad(c) if c.sum() > 0 else "" for c in ch], ch


def _minor(key: str) -> str:
    """The minor key of a key name of mlib.key_of ("G-Dur (= E-Moll)" -> "E-Moll")."""
    return key.split("(= ")[1].rstrip(")") if "(= " in key else key


def _root(name: str) -> int:
    return mlib.chord_root_pc(name) if name else -1


def check_title() -> dict:
    """The remaster against the original, bar by bar (both on the frozen timeline at 128 bpm): the pitch-class
    distribution of every bar (cosine of the two chroma vectors), the root of the best triad, and the key before the
    final chorus (it modulates a whole tone up, which pulls an estimate over the whole piece away)."""
    bars = ms.timeline(extra=False)
    starts = [b.t for b in bars]
    orig = _read(ORIGINAL)
    rem = _read(os.path.join(MUSIC, "titel_remaster.ogg"))
    co, cho = _chords(orig, starts, ms.BAR)
    cr, chr_ = _chords(rem, starts, ms.BAR)
    rows = []
    cos = []
    same = same_score_o = same_score_r = counted = 0
    for b, a, r, va, vr in zip(bars, co, cr, cho, chr_):
        want = b.chord
        if not a or not r:
            continue
        counted += 1
        c = float(np.dot(va, vr) / max(np.linalg.norm(va) * np.linalg.norm(vr), 1e-12))
        cos.append(c)
        ok = _root(a) == _root(r)
        same += ok
        same_score_o += _root(a) == _root(want)
        same_score_r += _root(r) == _root(want)
        rows.append({"bar": b.i + 1, "section": b.sec, "score": want, "original": a, "remaster": r, "same_root": ok,
                     "chroma_cos": round(c, 3)})
    pre = [i for i, b in enumerate(bars) if b.sec not in ("final", "outro")]
    key_o = mlib.key_of(cho[pre].sum(axis=0))
    key_r = mlib.key_of(chr_[pre].sum(axis=0))
    frac = same / max(counted, 1)
    med = float(np.median(cos)) if cos else 0.0
    res = {"bars": counted, "same_root": same, "same_root_frac": round(frac, 3),
           "chroma_cos_median": round(med, 3), "chroma_cos_min": round(float(min(cos)) if cos else 0.0, 3),
           "chroma_cos_ge_085": round(float(np.mean(np.array(cos) >= 0.85)) if cos else 0.0, 3),
           "original_vs_score": round(same_score_o / max(counted, 1), 3),
           "remaster_vs_score": round(same_score_r / max(counted, 1), 3),
           "key_original": key_o, "key_remaster": key_r, "differences": [r for r in rows if not r["same_root"]],
           "ok": _minor(key_o) == _minor(key_r) and med >= 0.9 and frac >= 0.85}
    return res


def check_race() -> dict:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import linke_spur as ls   # sets the tempo of the frozen synthesiser to 132 bpm for this process
    x = _read(os.path.join(MUSIC, ls.FILES["main"]))
    bars = [b for b in ls.BARS if b.i < ls.I_BODY + ls.LOOP_BARS]
    starts = [b.t for b in bars]
    cr, ch = _chords(x, starts, ls.BAR)
    hit = counted = 0
    misses = []
    for b, r in zip(bars, cr):
        if not r:
            continue
        counted += 1
        want = b.chord
        ok = _root(r) == _root(want)
        hit += ok
        if not ok:
            misses.append({"bar": b.i, "phrase": b.pid, "j": b.j, "score": want, "heard": r})
    key = mlib.key_of(ch[1:].sum(axis=0))
    # the ending: B♭ (first half of its first bar), C (second half), d (second bar)
    e = _read(os.path.join(MUSIC, ls.FILES["ending"]))
    half = ls.BAR / 2.0
    ce, _ = _chords(e, [0.0, half, ls.BAR], half)
    end_ok = [_root(c) for c in ce] == [mlib.chord_root_pc("Bb"), mlib.chord_root_pc("C"), mlib.chord_root_pc("Dm")]
    frac = hit / max(counted, 1)
    return {"bars": counted, "root_hits": hit, "root_frac": round(frac, 3), "key": key, "misses": misses,
            "ending": ce, "ending_ok": end_ok,
            "ok": frac >= 0.8 and _minor(key) == "D-Moll" and end_ok}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Musikalische Prüfung der Modern-Musik (Akkorde, Tonart)")
    ap.add_argument("--json", default="", help="vollständigen Bericht als JSON schreiben")
    args = ap.parse_args(argv)
    title = check_title()
    print("Titel-Remaster gegen die Titelmelodie von v0.5.0: Tonklassen je Takt gleich verteilt (Kosinus im Median %.3f, "
          "kleinster %.3f, %.0f %% der Takte >= 0,85); Akkord-Grundton in %d von %d Takten gleich (%.1f %%), Original gegen "
          "Partitur %.1f %%, Remaster gegen Partitur %.1f %%; Tonart vor dem Schlussrefrain %s / %s -> %s" % (
              title["chroma_cos_median"], title["chroma_cos_min"], 100 * title["chroma_cos_ge_085"], title["same_root"],
              title["bars"], 100 * title["same_root_frac"], 100 * title["original_vs_score"], 100 * title["remaster_vs_score"],
              title["key_original"], title["key_remaster"], "OK" if title["ok"] else "FEHLER"))
    for d in title["differences"][:12]:
        print("  Takt %3d %-8s Partitur %-4s Original %-4s Remaster %-4s" % (d["bar"], d["section"], d["score"], d["original"], d["remaster"]))
    race = check_race()
    print("Linke Spur gegen ihre Partitur: Grundton in %d von %d Takten (%.1f %%), Tonart %s; Schluss %s -> %s" % (
        race["root_hits"], race["bars"], 100 * race["root_frac"], race["key"], " – ".join(race["ending"]),
        "OK" if race["ok"] else "FEHLER"))
    for d in race["misses"][:12]:
        print("  Takt %3d %-3s %d  Partitur %-3s gehört %-4s" % (d["bar"], d["phrase"], d["j"], d["score"], d["heard"]))
    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump({"title": title, "race": race}, fh, ensure_ascii=False, indent=1)
            fh.write("\n")
    return 0 if title["ok"] and race["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
