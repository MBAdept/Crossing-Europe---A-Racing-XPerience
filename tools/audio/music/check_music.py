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


def _clip_roots(path: str, bar_s: float, layout: list) -> list:
    """Best triads of a clip: layout = [(start in bars, length in bars)]."""
    x = _read(path)
    out = []
    for a, n in layout:
        c, _ = _chords(x, [a * bar_s], n * bar_s)
        out.append(c[0])
    return out


def check_extras(piece: str, bpm: float, key: dict, ending: tuple) -> dict:
    """The extra clips of a race piece (race_lib.Extras): the stab on the tonic, the record ending on the cadence and
    the tonic, the finale ending in the major tonic (minor pieces: the Picardy third), the stingers on the (minor)
    tonic."""
    bar = 4.0 * 60.0 / bpm
    half = bar / 2.0
    f = lambda s: os.path.join(MUSIC, f"{piece}_{s}.ogg")  # noqa: E731
    T, Tm, TM = key["tonic"], key.get("minor_tonic", key["tonic"]), key.get("major_tonic", key["tonic"])
    got = {
        "ziel": _clip_roots(f("ziel"), bar, [(0, 0.5)]),
        "schluss_rekord": _clip_roots(f("schluss_rekord"), bar, [(0, 0.5), (0.5, 0.5), (1, 1)]),
        "schluss_finale": _clip_roots(f("schluss_finale"), bar, [(0, 0.5), (0.5, 0.5), (2, 1)]),
        "polizei": _clip_roots(f("polizei"), bar, [(0, 6 / 16)]),
        "tank": _clip_roots(f("tank"), bar, [(1, 0.5)]),
    }
    # the cadence halves (first two windows of the endings) are reported, not judged: half a bar of brass and guitar
    # chords is too short for the chroma (third harmonics of the fifths pull it to the neighbouring triad)
    want = {"ziel": [T], "schluss_rekord": [None, None, T], "schluss_finale": [None, None, TM]}
    res = {"clips": got, "ok": True, "misses": []}
    for k, w in want.items():
        for i, (g, ww) in enumerate(zip(got[k], w)):
            if ww is not None and _root(g) != mlib.chord_root_pc(ww):
                res["ok"] = False
                res["misses"].append(f"{k}[{i}]: Partitur {ww}, gehört {g}")
    # the stingers sound over the running piece: their key (all bars of the clip) is the minor tonic of the piece
    minor = mlib.NOTE_NAMES[mlib.chord_root_pc(Tm)] + "-Moll"
    for k, nb in (("polizei", 3), ("tank", 2)):
        x = _read(f(k))
        _c, chs = _chords(x, [i * bar for i in range(nb)], bar)
        kk = _minor(mlib.key_of(chs.sum(axis=0)))
        res["clips"][k] = res["clips"][k] + [f"Tonart {kk}"]
        if kk != minor:
            res["ok"] = False
            res["misses"].append(f"{k}: Tonart {kk} statt {minor}")
    # the finale ends in major: its last chord is a major triad (no "m")
    fin = got["schluss_finale"][-1]
    res["finale_major"] = bool(fin) and not fin.endswith("m")
    res["ok"] = res["ok"] and res["finale_major"]
    _ = half
    return res


def check_piece(name: str) -> dict:
    """A race piece of race_lib (nachtfahrt, rueckenwind) against its own score: the root of the best triad per bar of
    the main file (count-in, first phrase, loop), the key, the ending (cadence – tonic) and its extra clips."""
    import importlib
    mod = importlib.import_module(name)
    cls = next(v for v in vars(mod).values() if isinstance(v, type) and getattr(v, "PIECE", "") == name)
    pc = cls()                          # sets the tempo of the frozen synthesiser for this piece
    bar_s = 4.0 * 60.0 / pc.BPM
    x = _read(os.path.join(MUSIC, pc.files["main"]))
    bars = [b for b in pc.tl.bars if b.i < pc.I_BODY + pc.LOOP_BARS]
    cr, ch = _chords(x, [b.i * bar_s for b in bars], bar_s)
    hit = counted = 0
    misses = []
    colour = getattr(mod, "COLOUR", {})
    import race_lib
    for b, r in zip(bars, cr):
        if not r:
            continue
        counted += 1
        # a hit: the root of the score's chord, or a triad made of the notes the pad really holds (Abmaj7 contains
        # C minor, Cm9 E-flat major – the colour tones of the pieces make these the best triad of the bar)
        cpc, civ = race_lib.parse_chord(colour.get(b.chord, b.chord))
        held = {(cpc + i) % 12 for i in civ}
        rp, riv = race_lib.parse_chord(r.replace("A#", "Bb").replace("D#", "Eb").replace("G#", "Ab"))
        inside = all((rp + i) % 12 in held for i in riv)
        ok = _root(r) == _root(b.chord) or inside
        hit += ok
        if not ok:
            misses.append({"bar": b.i, "phrase": b.pid, "j": b.j, "score": b.chord, "heard": r})
    key = mlib.key_of(ch[1:].sum(axis=0))
    want_key = {"Cm": "C-Moll", "A": "F#-Moll"}.get(pc.KEY["tonic"], "")
    e = _read(os.path.join(MUSIC, pc.files["ending"]))
    half = bar_s / 2.0
    ce, _ = _chords(e, [0.0, half, bar_s], half)
    # judged: the first chord and the arrival on the tonic; the second half bar is reported (see check_extras)
    end_ok = _root(ce[0]) == mlib.chord_root_pc(pc.ENDING[0]) and _root(ce[2]) == mlib.chord_root_pc(pc.ENDING[2])
    frac = hit / max(counted, 1)
    ex = check_extras(name, pc.BPM, pc.KEY, pc.ENDING)
    return {"bars": counted, "root_hits": hit, "root_frac": round(frac, 3), "key": key, "misses": misses,
            "ending": ce, "ending_ok": end_ok, "extras": ex,
            "ok": frac >= 0.8 and _minor(key) == want_key and end_ok and ex["ok"]}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Musikalische Prüfung der Modern-Musik (Akkorde, Tonart)")
    ap.add_argument("--json", default="", help="vollständigen Bericht als JSON schreiben")
    ap.add_argument("--only", default="", help="nur diese Prüfungen (Komma-Liste: titel, linke_spur, nachtfahrt, "
                                               "rueckenwind)")
    ap.add_argument("--music", default="", help="Musikordner statt assets/audio/modern/music (z. B. ein --out-Lauf)")
    args = ap.parse_args(argv)
    if args.music:
        global MUSIC
        MUSIC = args.music
    only = [s for s in args.only.split(",") if s]
    if only:
        return _main_only(only, args.json)
    title = check_title()
    print("Titel-Remaster gegen die Titelmelodie von v0.5.0: Tonklassen je Takt gleich verteilt (Kosinus im Median %.3f, "
          "kleinster %.3f, %.0f %% der Takte >= 0,85); Akkord-Grundton in %d von %d Takten gleich (%.1f %%), Original gegen "
          "Partitur %.1f %%, Remaster gegen Partitur %.1f %%; Tonart vor dem Schlussrefrain %s / %s -> %s" % (
              title["chroma_cos_median"], title["chroma_cos_min"], 100 * title["chroma_cos_ge_085"], title["same_root"],
              title["bars"], 100 * title["same_root_frac"], 100 * title["original_vs_score"], 100 * title["remaster_vs_score"],
              title["key_original"], title["key_remaster"], "OK" if title["ok"] else "FEHLER"))
    for d in title["differences"][:12]:
        print("  Takt %3d %-8s Partitur %-4s Original %-4s Remaster %-4s" % (d["bar"], d["section"], d["score"], d["original"], d["remaster"]))
    rep = {"title": title}
    ok = title["ok"]
    for name in ("linke_spur", "nachtfahrt", "rueckenwind"):
        rep[name] = _report_race(name)
        ok = ok and rep[name]["ok"]
    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(rep, fh, ensure_ascii=False, indent=1)
            fh.write("\n")
    return 0 if ok else 1


def _report_race(name: str) -> dict:
    if name == "linke_spur":
        race = check_race()
        import linke_spur as ls
        race["extras"] = check_extras("linke_spur", ls.BPM, ls.KEY, ("Bb", "C", "Dm"))
        race["ok"] = race["ok"] and race["extras"]["ok"]
        label = "Linke Spur"
    else:
        race = check_piece(name)
        label = {"nachtfahrt": "Nachtfahrt", "rueckenwind": "Rückenwind"}[name]
    ex = race["extras"]
    print("%s gegen ihre Partitur: Grundton in %d von %d Takten (%.1f %%), Tonart %s; Schluss %s; Zusatzclips %s%s -> %s" % (
        label, race["root_hits"], race["bars"], 100 * race["root_frac"], race["key"], " – ".join(race["ending"]),
        "; ".join(f"{k} {' – '.join(v)}" for k, v in ex["clips"].items()),
        "" if ex["finale_major"] else " (FINALE NICHT IN DUR)", "OK" if race["ok"] else "FEHLER"))
    for d in race["misses"][:12]:
        print("  Takt %3d %-3s %d  Partitur %-3s gehört %-4s" % (d["bar"], d["phrase"], d["j"], d["score"], d["heard"]))
    for m in ex["misses"]:
        print("  " + m)
    return race


def _main_only(only: list, json_path: str) -> int:
    rep = {}
    ok = True
    for name in only:
        if name == "titel":
            rep[name] = check_title()
            print("Titel-Remaster: %s" % ("OK" if rep[name]["ok"] else "FEHLER"))
        else:
            rep[name] = _report_race(name)
        ok = ok and rep[name]["ok"]
    if json_path:
        with open(json_path, "w", encoding="utf-8") as fh:
            json.dump(rep, fh, ensure_ascii=False, indent=1)
            fh.write("\n")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
