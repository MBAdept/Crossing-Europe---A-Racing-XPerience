#!/usr/bin/env python3
"""Quality check of the sound files of the profile "Modern" (contract §4.7.3): assets/audio/modern/<folder>/ with
their manifest.json (format "ce-audio-manifest-1").

    python3 tools/audio/qc/audio_qc.py                    every folder: files, manifests, Godot import settings, sizes
    python3 tools/audio/qc/audio_qc.py --determinism      also runs every generator named in the manifests twice
                                                          (--out <tmp>) and compares the bytes with each other and
                                                          with the committed files
    python3 tools/audio/qc/audio_qc.py --folders ui,music --json report.json

Per sound (each file of an entry):
  format        the kind fits the folder rules: music and ambience Ogg Vorbis, loops and one-shots 16-bit WAV, all
                44.1 kHz; engine data raw int16 at 32 kHz stereo
  manifest      the file is what the manifest says: sha256, bytes, frames, channels, sample rate, loudness and true
                peak (re-measured: BS.1770 integrated loudness, 4x oversampled peak)
  level         true peak <= -1 dBTP; music at -14 +-1 LUFS (masters); an entry may set its own limits:
                "qc": {"lufs": [lo, hi], "true_peak_max": dB, "seam_max": ratio, "dc_max": dB}
  clipping      no run of 3 or more samples at full scale; DC offset below -40 dBFS
  loop          the loop points lie inside the file; the seam is no click: its step and kink are at most 2x (WAV) /
                4x (after Vorbis) the largest ones within 100 ms around it – or, where a beat sits on the loop
                point, no larger than the largest ones anywhere in the loop
  import        the .import file next to the sound says the same as the manifest (loop mode and points, PCM without
                compression; for Ogg: loop, loop_offset, bpm, beat_count, bar_beats)
Per folder: a file the manifest does not know is an error – the export takes every file of the folder
(export filter all_resources), and such a file would ship without any loudness, peak or seam check.
--allow-unknown turns that into a hint (work in progress). Overall: bytes per folder against the budgets of
contract §4.11 (sounds <= 23 MB, music <= 25 MB), loudness range and short-term maximum as information.

Exit code 0 = everything passes. Lines: "QC <folder>/<id> OK|FEHLER ..."; with --json the full numbers.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import qc_lib  # noqa: E402

ASSETS_REL = "assets/audio/modern"
FOLDERS = ["engines", "vehicle", "traffic", "sfx", "ambience", "ui", "music"]
FORMAT = "ce-audio-manifest-1"
KINDS = ("oneshot", "loop", "music", "bank")
SR = 44100
BANK_SR = 32000
TRUE_PEAK_MAX = -1.0
MUSIC_LUFS = (-15.0, -13.0)
SEAM_MAX = {"wav": 2.0, "ogg": 4.0, "i16": 2.0}
DC_MAX = -40.0
TOL_DB = 0.1
BUDGET_MB = {"sounds": 23.0, "music": 25.0}
META_FILES = ("manifest.json",)


def read_import(path: str) -> dict | None:
    """The [params] of a Godot .import file as {key: text}."""
    imp = path + ".import"
    if not os.path.exists(imp):
        return None
    out: dict = {}
    section = ""
    with open(imp, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line.startswith("["):
                section = line
            elif "=" in line and section in ("[params]", "[remap]"):
                k, v = line.split("=", 1)
                out[k] = v.strip('"')
    return out


class Report:
    def __init__(self) -> None:
        self.sounds: list[dict] = []
        self.problems: list[str] = []
        self.warnings: list[str] = []
        self.folders: dict[str, dict] = {}
        self.determinism: list[dict] = []

    def problem(self, text: str) -> None:
        self.problems.append(text)


def check_sound(folder: str, sid: str, e: dict, base: str, with_import: bool, rep: Report) -> None:
    where = f"{folder}/{sid}"
    errs: list[str] = []
    kind = e.get("kind", "")
    if kind not in KINDS:
        rep.problem(f"{where}: unbekannte Art {kind!r}")
        print(f"QC {where:34s} FEHLER unbekannte Art {kind!r}")
        return
    names = e.get("files") or ([e["file"]] if "file" in e else [])
    if not names:
        rep.problem(f"{where}: weder file noch files")
        print(f"QC {where:34s} FEHLER weder file noch files")
        return
    qc = e.get("qc", {}) or {}
    many = len(names) > 1
    info_all: list[dict] = []
    for i, name in enumerate(names):
        path = os.path.join(base, folder, name)
        ext = name.rsplit(".", 1)[-1].lower()
        if not os.path.exists(path):
            errs.append(f"{name} fehlt")
            continue
        # --- format rules
        want_ext = {"bank": ("i16",), "music": ("ogg",)}.get(kind, ("ogg",) if folder == "ambience" else ("wav",))
        if ext not in want_ext:
            errs.append(f"{name}: Art {kind} in {folder} erwartet .{'/.'.join(want_ext)}")
            continue
        if kind == "bank":
            ch = int(e.get("channels", 2))
            try:
                x = qc_lib.read_i16(path, ch)
            except ValueError as err:
                errs.append(str(err))
                continue
            sr = int(e.get("sample_rate", BANK_SR))
            if sr != BANK_SR or ch != 2:
                errs.append(f"{name}: Motordaten brauchen {BANK_SR} Hz Stereo (Manifest: {sr} Hz, {ch} Kanäle)")
        else:
            try:
                x, sr = qc_lib.read_audio(path)
            except (ValueError, subprocess.CalledProcessError) as err:
                errs.append(f"{name}: nicht lesbar ({err})")
                continue
            if sr != SR:
                errs.append(f"{name}: {sr} Hz statt {SR} Hz")
            if ext == "wav" and qc_lib.wav_info(path)["bits"] != 16:
                errs.append(f"{name}: {qc_lib.wav_info(path)['bits']} Bit statt 16 Bit")
        m = qc_lib.measure(x, sr)
        m.update({"file": name, "frames": int(len(x)), "channels": int(x.shape[1]), "sample_rate": sr,
                  "bytes": os.path.getsize(path), "sha256": qc_lib.sha256(path), "seconds": round(len(x) / sr, 3)})
        # --- manifest says what the file is
        def listed(key: str):
            v = e.get(key)
            return v[i] if (many and isinstance(v, list)) else v
        for key in ("sha256", "bytes"):
            if listed(key) != m[key]:
                errs.append(f"{name}: {key} im Manifest {listed(key)!r}, Datei {m[key]!r}")
        for key in ("frames", "channels", "sample_rate"):
            if (not many or i == 0) and e.get(key) != m[key]:
                errs.append(f"{name}: {key} im Manifest {e.get(key)!r}, Datei {m[key]!r}")
        if not many:
            for key in ("lufs", "true_peak_db"):
                if not isinstance(e.get(key), (int, float)) or abs(float(e[key]) - m[key]) > TOL_DB:
                    errs.append(f"{name}: {key} im Manifest {e.get(key)!r}, gemessen {m[key]}")
        # --- levels
        tp_max = float(qc.get("true_peak_max", TRUE_PEAK_MAX))
        if m["true_peak_db"] > tp_max:
            errs.append(f"{name}: True Peak {m['true_peak_db']} dBTP über {tp_max}")
        lufs_range = qc.get("lufs", MUSIC_LUFS if kind == "music" else None)
        if lufs_range and not (lufs_range[0] <= m["lufs"] <= lufs_range[1]):
            errs.append(f"{name}: {m['lufs']} LUFS außerhalb {lufs_range[0]} … {lufs_range[1]}")
        if m["clipped_runs"]:
            errs.append(f"{name}: {m['clipped_runs']} übersteuerte Stellen")
        if m["dc_db"] > float(qc.get("dc_max", DC_MAX)):
            errs.append(f"{name}: Gleichanteil {m['dc_db']} dBFS")
        # --- loop
        loop = e.get("loop")
        if kind == "loop" and not loop:
            errs.append(f"{name}: Art loop ohne Schleifenpunkte")
        if loop:
            a, b = int(loop[0]), int(loop[1])
            if not (0 <= a < b <= len(x)):
                errs.append(f"{name}: Schleife {loop} außerhalb der Datei ({len(x)} Frames)")
            else:
                seam = qc_lib.loop_seam(x, a, b, 0.1, sr)
                m["seam_ratio"] = round(seam["ratio"], 2)
                m["seam_kink_ratio"] = round(seam["kink_ratio"], 2)
                m["seam_loop_ratio"] = round(max(seam["loop_ratio"], seam["loop_kink_ratio"]), 2)
                lim = float(qc.get("seam_max", SEAM_MAX[ext]))
                click = (seam["ratio"] > lim and seam["loop_ratio"] > 1.0) or \
                        (seam["kink_ratio"] > lim and seam["loop_kink_ratio"] > 1.0)
                if click:
                    errs.append(f"{name}: Schleifennaht rauer als ihr Umfeld (Sprung ×{seam['ratio']:.2f}, "
                                f"Knick ×{seam['kink_ratio']:.2f}, erlaubt ×{lim:g}) und als jede andere Stelle "
                                f"der Schleife (×{m['seam_loop_ratio']:.2f})")
                if ext == "ogg" and b != len(x):
                    errs.append(f"{name}: eine Ogg-Schleife endet am Dateiende ({len(x)}), nicht bei {b}")
        # --- Godot import settings
        if with_import and kind != "bank":
            p = read_import(path)
            if p is None:
                errs.append(f"{name}: .import fehlt")
            elif ext == "wav":
                want = {"edit/loop_mode": "2" if loop else "1", "compress/mode": "0", "force/mono": "false",
                        "force/8_bit": "false", "force/max_rate": "false", "edit/trim": "false", "edit/normalize": "false"}
                if loop:
                    want["edit/loop_begin"] = str(int(loop[0]))
                    want["edit/loop_end"] = str(int(loop[1]))
                for k, v in want.items():
                    if p.get(k) != v:
                        errs.append(f"{name}.import: {k}={p.get(k)} statt {v}")
            else:
                if p.get("loop") != ("true" if loop else "false"):
                    errs.append(f"{name}.import: loop={p.get('loop')}")
                if loop and abs(float(p.get("loop_offset", "0")) - loop[0] / sr) > 0.5 / sr:
                    errs.append(f"{name}.import: loop_offset={p.get('loop_offset')} statt {loop[0] / sr:g}")
                for key, imp_key in (("bpm", "bpm"), ("beats", "beat_count"), ("bar_beats", "bar_beats")):
                    if key in e and abs(float(p.get(imp_key, "0")) - float(e[key])) > 1e-6:
                        errs.append(f"{name}.import: {imp_key}={p.get(imp_key)} statt {e[key]}")
        info_all.append(m)
    # music: tempo data must describe the file
    if kind == "music" and e.get("bpm") and e.get("beats") and info_all:
        want_s = float(e["beats"]) * 60.0 / float(e["bpm"])
        loop = e.get("loop")
        have_s = ((loop[1] - loop[0]) if loop else info_all[0]["frames"]) / float(info_all[0]["sample_rate"])
        if abs(want_s - have_s) > 0.002:
            errs.append(f"{e['beats']} Schläge bei {e['bpm']} bpm sind {want_s:.3f} s, die Schleife hat {have_s:.3f} s")
    rep.sounds.append({"folder": folder, "id": sid, "kind": kind, "placeholder": bool(e.get("placeholder", False)),
                       "generator": e.get("generator", ""), "files": info_all, "errors": errs})
    for err in errs:
        rep.problem(f"{where}: {err}")
    if info_all:
        m0 = info_all[0]
        text = "%6.1f LUFS %6.1f dBTP %7.2f s %s %7.1f kB" % (m0["lufs"], m0["true_peak_db"], m0["seconds"],
                                                              "mono  " if m0["channels"] == 1 else "stereo", sum(i["bytes"] for i in info_all) / 1024.0)
        if "seam_ratio" in m0:
            text += "  Naht ×%.2f" % min(max(m0["seam_ratio"], m0["seam_kink_ratio"]), m0["seam_loop_ratio"])
        if many:
            text += f"  ({len(names)} Varianten)"
        if e.get("placeholder"):
            text += "  [Platzhalter]"
    else:
        text = ""
    print(f"QC {where:34s} {'OK    ' if not errs else 'FEHLER'} {text}")
    for err in errs:
        print(f"     - {err}")


def check_folder(folder: str, base: str, with_import: bool, rep: Report, allow_unknown: bool = False) -> None:
    d = os.path.join(base, folder)
    mpath = os.path.join(d, "manifest.json")
    info = {"files": 0, "bytes": 0, "sounds": 0, "placeholders": 0}
    rep.folders[folder] = info
    if not os.path.exists(mpath):
        rep.warnings.append(f"{folder}: kein manifest.json (noch keine Klänge)")
        print(f"QC {folder + '/':34s} –      kein Manifest")
        return
    try:
        with open(mpath, encoding="utf-8") as fh:
            man = json.load(fh)
    except json.JSONDecodeError as err:
        rep.problem(f"{folder}/manifest.json: {err}")
        return
    if man.get("format") != FORMAT or man.get("folder") != folder or not isinstance(man.get("sounds"), dict):
        rep.problem(f"{folder}/manifest.json: Format {man.get('format')!r}, Ordner {man.get('folder')!r}")
        return
    known = set(META_FILES)
    for sid in sorted(man["sounds"]):
        e = man["sounds"][sid]
        check_sound(folder, sid, e, base, with_import, rep)
        for name in e.get("files") or ([e["file"]] if "file" in e else []):
            known.add(name)
            known.add(name + ".import")
            if e.get("kind") == "bank":
                known.add(name.rsplit(".", 1)[0] + ".json")
        info["sounds"] += 1
        info["placeholders"] += 1 if e.get("placeholder") else 0
    for name in sorted(os.listdir(d)):
        p = os.path.join(d, name)
        if not os.path.isfile(p):
            continue
        info["files"] += 1
        info["bytes"] += os.path.getsize(p)
        if name not in known and not name.endswith(".uid"):
            text = f"{folder}/{name}: steht in keinem Manifest-Eintrag"
            if allow_unknown:
                rep.warnings.append(text + " (ungeprüft, --allow-unknown)")
            else:
                rep.problem(text + " – ungeprüfte Datei im Export (Eintrag ergänzen oder Datei entfernen)")
                print(f"QC {folder + '/' + name:34s} FEHLER steht in keinem Manifest-Eintrag")


def size_report(rep: Report, budgets: dict) -> None:
    sounds = sum(v["bytes"] for k, v in rep.folders.items() if k != "music")
    music = rep.folders.get("music", {}).get("bytes", 0)
    print("\nGröße (Bytes der Dateien im Ordner; Budget nach Vertrag §4.11):")
    for folder in rep.folders:
        v = rep.folders[folder]
        print(f"  {folder:9s} {v['bytes'] / 1e6:8.3f} MB  {v['sounds']:3d} Klänge ({v['placeholders']} Platzhalter)")
    for name, used in (("sounds", sounds), ("music", music)):
        lim = budgets[name]
        mark = "OK" if used <= lim * 1e6 else "FEHLER"
        print(f"  Summe {'Klänge' if name == 'sounds' else 'Musik'}: {used / 1e6:.3f} MB von {lim:g} MB  {mark}")
        if used > lim * 1e6:
            rep.problem(f"Größe {name}: {used / 1e6:.2f} MB über dem Budget von {lim:g} MB")
        elif used > 0.9 * lim * 1e6:
            rep.warnings.append(f"Größe {name}: {used / 1e6:.2f} MB – über 90 % des Budgets")


def check_determinism(base: str, folders: list[str], rep: Report) -> None:
    """Runs every generator of the manifests twice into temporary folders: the two runs must be identical, and the
    files and manifest entries they write must be the committed ones."""
    gens: dict[str, list[tuple[str, str]]] = {}
    for folder in folders:
        mpath = os.path.join(base, folder, "manifest.json")
        if not os.path.exists(mpath):
            continue
        with open(mpath, encoding="utf-8") as fh:
            man = json.load(fh)
        for sid, e in man.get("sounds", {}).items():
            if e.get("generator"):
                gens.setdefault(e["generator"], []).append((folder, sid))
    print("\nDeterminismus (jeder Generator zweimal nach --out):")
    for gen in sorted(gens):
        script = os.path.join(ROOT, gen)
        entry = {"generator": gen, "ok": False, "files": 0, "diff": []}
        rep.determinism.append(entry)
        if not os.path.exists(script):
            rep.problem(f"Generator {gen} fehlt")
            print(f"  {gen}: FEHLER (Datei fehlt)")
            continue
        with tempfile.TemporaryDirectory(prefix="ce_qc_a_") as ta, tempfile.TemporaryDirectory(prefix="ce_qc_b_") as tb:
            ok_run = True
            for t in (ta, tb):
                r = subprocess.run([sys.executable, script, "--out", t], capture_output=True, text=True)
                if r.returncode != 0:
                    rep.problem(f"Generator {gen}: Lauf fehlgeschlagen: {r.stderr.strip()[-300:]}")
                    ok_run = False
                    break
            if not ok_run:
                print(f"  {gen}: FEHLER (Lauf fehlgeschlagen)")
                continue
            ra = os.path.join(ta, ASSETS_REL)
            rb = os.path.join(tb, ASSETS_REL)
            for dirpath, _dirs, files in os.walk(ra):
                for name in sorted(files):
                    pa = os.path.join(dirpath, name)
                    rel = os.path.relpath(pa, ra)
                    pb = os.path.join(rb, rel)
                    entry["files"] += 1
                    if not os.path.exists(pb) or qc_lib.sha256(pa) != qc_lib.sha256(pb):
                        entry["diff"].append(f"{rel}: zwei Läufe unterscheiden sich")
                        continue
                    if name == "manifest.json":
                        continue        # the repository's manifest may hold entries of other generators
                    pc = os.path.join(base, rel)
                    if not os.path.exists(pc):
                        entry["diff"].append(f"{rel}: fehlt im Repository")
                    elif qc_lib.sha256(pa) != qc_lib.sha256(pc):
                        entry["diff"].append(f"{rel}: Repository-Datei ist nicht die des Generators")
            # manifest entries of this generator: identical to the committed ones
            for folder, sid in gens[gen]:
                ma = os.path.join(ra, folder, "manifest.json")
                if not os.path.exists(ma):
                    entry["diff"].append(f"{folder}/{sid}: der Generator schreibt kein Manifest für {folder}")
                    continue
                with open(ma, encoding="utf-8") as fh:
                    fresh = json.load(fh).get("sounds", {}).get(sid)
                with open(os.path.join(base, folder, "manifest.json"), encoding="utf-8") as fh:
                    committed = json.load(fh)["sounds"][sid]
                if fresh != committed:
                    entry["diff"].append(f"{folder}/{sid}: Manifest-Eintrag weicht vom Generator ab")
        entry["ok"] = not entry["diff"]
        for dline in entry["diff"]:
            rep.problem(f"Determinismus {gen}: {dline}")
        print(f"  {gen}: {'OK' if entry['ok'] else 'FEHLER'}  ({entry['files']} Dateien je Lauf, {len(gens[gen])} Einträge)")
        for dline in entry["diff"]:
            print(f"     - {dline}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Qualitätsprüfung der Modern-Klangdateien (siehe Kopf der Datei)")
    ap.add_argument("--root", default=os.path.join(ROOT, ASSETS_REL), help="Ordner mit den Klang-Unterordnern")
    ap.add_argument("--folders", default=",".join(FOLDERS), help="nur diese Unterordner (Komma-Liste)")
    ap.add_argument("--determinism", action="store_true", help="Generatoren zweimal laufen lassen und vergleichen")
    ap.add_argument("--no-import", action="store_true", help=".import-Dateien nicht prüfen (z. B. für --out-Ordner)")
    ap.add_argument("--budget-sounds-mb", type=float, default=BUDGET_MB["sounds"])
    ap.add_argument("--budget-music-mb", type=float, default=BUDGET_MB["music"])
    ap.add_argument("--json", default="", help="vollständigen Bericht als JSON schreiben")
    ap.add_argument("--allow-unknown", action="store_true",
                    help="Dateien ohne Manifest-Eintrag nur als Hinweis melden (Arbeitsstand), nicht als Fehler")
    args = ap.parse_args()
    folders = [f for f in args.folders.split(",") if f]
    for f in folders:
        if f not in FOLDERS:
            print(f"unbekannter Ordner {f}")
            return 2
    rep = Report()
    for folder in folders:
        check_folder(folder, args.root, not args.no_import, rep, args.allow_unknown)
    size_report(rep, {"sounds": args.budget_sounds_mb, "music": args.budget_music_mb})
    if args.determinism:
        check_determinism(args.root, folders, rep)
    if rep.warnings:
        print("\nHinweise:")
        for w in rep.warnings:
            print(f"  - {w}")
    n = len(rep.sounds)
    bad = sum(1 for s in rep.sounds if s["errors"])
    print(f"\n{n} Klänge geprüft, {bad} mit Fehlern, {len(rep.problems)} Probleme insgesamt"
          f" -> {'OK' if not rep.problems else 'FEHLER'}")
    if args.json:
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump({"ok": not rep.problems, "problems": rep.problems, "warnings": rep.warnings, "folders": rep.folders,
                       "sounds": rep.sounds, "determinism": rep.determinism}, fh, ensure_ascii=False, indent=1)
            fh.write("\n")
    return 0 if not rep.problems else 1


if __name__ == "__main__":
    sys.exit(main())
