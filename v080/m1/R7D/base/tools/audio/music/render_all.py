#!/usr/bin/env python3
"""Renders every piece of the Modern music again (docs/audio-modern.md, section "Musik"): after a change of the shared
mix decisions in tools/audio/music/mischung.json (sub, bass, high shelf, music levels) all pieces come out the same
way. One generator after the other (each is a heavy job of 2-10 minutes on one core; run it with `nice -n 19`):

  title_remaster.py   titel_remaster.ogg                       (role title)
  linke_spur.py       linke_spur*.ogg                          (race piece 1, its ending and extra clips)
  nachtfahrt.py       nachtfahrt*.ogg                          (race piece 2 …)
  rueckenwind.py      rueckenwind*.ogg                         (race piece 3 …)
  zwischenspiel.py    zwischenspiel.ogg                        (role interlude)
  ui_klaenge.py       assets/audio/modern/ui/ui_*.wav          (menu sounds)

  python3 tools/audio/music/render_all.py                          all of them into the repository (with imports)
  python3 tools/audio/music/render_all.py --only nachtfahrt,ui_klaenge
  python3 tools/audio/music/render_all.py --out DIR --wav DIR      below DIR, float masters for previews
Afterwards: godot --headless --path . --import, then python3 tools/audio/qc/audio_qc.py --folders music,ui and
python3 tools/audio/music/check_music.py. A change that only moves race_music_db, menu_music_db or ui_db needs no new
rendering of the sound – the generators write it into the manifest – but the run is the way to get it there.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ORDER = ["title_remaster", "linke_spur", "nachtfahrt", "rueckenwind", "zwischenspiel", "ui_klaenge"]
NO_WAV = {"ui_klaenge"}           # writes its demo file to --wav, not a master


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Alle Musikstücke des Klangprofils Modern neu rendern")
    ap.add_argument("--only", default="", help="nur diese Generatoren (Komma-Liste: " + ", ".join(ORDER) + ")")
    ap.add_argument("--out", default="", help="statt ins Repository unter diesen Ordner schreiben (ohne .import)")
    ap.add_argument("--wav", default="", help="die Master (Float-WAV) bzw. die Hörprobe der UI-Klänge hier ablegen")
    args = ap.parse_args(argv)
    only = [s for s in args.only.split(",") if s] or ORDER
    for name in only:
        if name not in ORDER:
            print(f"unbekannter Generator {name}")
            return 2
    failed = []
    for name in ORDER:
        if name not in only:
            continue
        cmd = [sys.executable, os.path.join(HERE, name + ".py")]
        if args.out:
            cmd += ["--out", args.out]
        if args.wav:
            cmd += ["--wav", args.wav]
        t0 = time.time()
        print(f"== {name}", flush=True)
        r = subprocess.run(cmd)
        print(f"== {name}: {'OK' if r.returncode == 0 else 'FEHLER'} nach {time.time() - t0:.0f} s", flush=True)
        if r.returncode != 0:
            failed.append(name)
    print("FERTIG" if not failed else "FEHLER in " + ", ".join(failed))
    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
