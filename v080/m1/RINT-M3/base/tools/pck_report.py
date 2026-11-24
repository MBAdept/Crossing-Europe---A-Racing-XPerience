#!/usr/bin/env python3
"""Size table and size gate of a build (v0.8.0, docs/dev/v080_contract.md §4.11, Rule 6).

Reads the game data (PCK) embedded in an exported executable – or a bare .pck –, sorts every file into the
parts of the size budget and prints per part: files, raw megabytes and megabytes in the release archive
(deflate -9 per file: zip -9 and gzip -9 use the same compression, so the sum is close to the real archive).

    tools/pck_report.py build/CrossingEurope.exe --archive build/CrossingEurope-windows-x86_64.zip
    tools/pck_report.py build/CrossingEurope.x86_64              (gate on the estimated sum)
    tools/pck_report.py --gate-only --archive build/CrossingEurope-linux-x86_64.tar.gz

Gate (megabytes = 1,000,000 bytes): the archive must stay below 350 MB; this tool warns above 300 MB and fails
(exit code 1) above 330 MB. A part above its own budget is reported (exit code 1 only with --strict).
Options: --archive FILE (the real archive: its size is what the gate judges), --warn-mb N, --fail-mb N,
--no-gate, --strict, --gate-only, --top N (largest files), --tsv FILE (every file: bytes, deflate bytes, part,
source path, path in the PCK), --json FILE, --no-deflate (raw sizes only, fast; no archive estimate).

Parts: the executable around the PCK is the engine template; inside the PCK imported files are mapped back to
their sources through the .import files the PCK carries, and the source path decides: assets/sprites = Arcade
sprites, assets/audio except assets/audio/modern = Arcade audio, assets/models = Modern meshes (images below it:
Modern textures), assets/audio/modern = Modern sounds (music/ below it: Modern music), everything else = UI,
fonts, scripts, data. Needs only Python 3 (no project folder, no Godot).
"""
import argparse
import json
import os
import re
import struct
import sys
import time
import zlib

MB = 1_000_000.0
PCK_MAGIC = b"GDPC"
PACK_REL_FILEBASE = 1 << 1
IMAGE_EXT = (".png", ".webp", ".jpg", ".jpeg", ".svg", ".exr", ".hdr", ".ctex", ".ktx", ".dds")

# id, German label, budget in the archive (MB; None = no own budget), tolerance factor for "unchanged" parts
PARTS = [
    ("engine", "Programm (Godot-Vorlage)", 38.0, 1.02),
    ("arcade_sprites", "Arcade-Sprites", 71.0, 1.02),
    ("arcade_audio", "Arcade-Klang und -Musik", 14.7, 1.02),
    ("ui_scripts_data", "UI, Schriften, Skripte, Daten", 5.0, 1.0),
    ("modern_meshes", "Modern: Modelle (Meshes)", 40.0, 1.0),
    ("modern_textures", "Modern: Texturen", 60.0, 1.0),
    ("modern_sounds", "Modern: Klang", 23.0, 1.0),
    ("modern_music", "Modern: Musik", 25.0, 1.0),
]
TOTAL_BUDGET_MB = 277.0
WARN_MB = 300.0
FAIL_MB = 330.0
HARD_MB = 350.0


class PckError(Exception):
    pass


def read_pck(path):
    """Directory of the PCK in `path`: ({start, end, godot, version, flags, file_base, size}, [(path, offset, size, flags)])."""
    total = os.path.getsize(path)
    with open(path, "rb") as f:
        start = 0
        end = total
        if f.read(4) != PCK_MAGIC:
            # embedded: the file ends with <u64 size of the PCK> "GDPC"
            if total < 16:
                raise PckError("Datei zu klein")
            f.seek(total - 12)
            tail = f.read(12)
            if tail[8:] != PCK_MAGIC:
                raise PckError("kein eingebettetes PCK (die Datei endet nicht mit der Marke GDPC)")
            (pck_size,) = struct.unpack("<Q", tail[:8])
            start = total - 12 - pck_size
            end = total - 12
            if start < 0:
                raise PckError("PCK-Größe am Dateiende passt nicht zur Datei")
        f.seek(start)
        if f.read(4) != PCK_MAGIC:
            raise PckError("PCK beginnt nicht mit GDPC")
        version, major, minor, patch, flags = struct.unpack("<5I", f.read(20))
        (file_base,) = struct.unpack("<Q", f.read(8))
        # Format 2 (Godot 4.0–4.3): directory right after the header. Formats 3 and 4 (Godot 4.4+, 4.7 writes 4):
        # an offset to the directory follows the file base; offsets are relative to the start of the PCK.
        if version < 2 or version > 4:
            raise PckError("PCK-Formatversion %d wird nicht unterstützt (bekannt: 2 bis 4, Godot 4.0–4.7)" % version)
        dir_offset = None
        if version >= 3:
            (dir_offset,) = struct.unpack("<Q", f.read(8))
        f.read(64)  # reserved
        if dir_offset is not None:
            f.seek(start + dir_offset)
        if flags & PACK_REL_FILEBASE or version >= 3:
            file_base += start
        (count,) = struct.unpack("<I", f.read(4))
        if count > 1_000_000:
            raise PckError("unplausible Dateizahl %d" % count)
        files = []
        for _ in range(count):
            (plen,) = struct.unpack("<I", f.read(4))
            name = f.read(plen).rstrip(b"\0").decode("utf-8", "replace")
            offset, size = struct.unpack("<QQ", f.read(16))
            f.read(16)  # md5
            (fflags,) = struct.unpack("<I", f.read(4))
            if name.startswith("res://"):
                name = name[6:]
            files.append((name, file_base + offset, size, fflags))
    info = {"start": start, "end": end, "godot": "%d.%d.%d" % (major, minor, patch), "version": version, "flags": flags,
            "size": total, "count": len(files)}
    return info, files


def part_of(source):
    """Budget part of a source path (res:// relative)."""
    p = source.lower()
    if p.startswith("assets/sprites/"):
        return "arcade_sprites"
    if p.startswith("assets/audio/modern/music/"):
        return "modern_music"
    if p.startswith("assets/audio/modern/"):
        return "modern_sounds"
    if p.startswith("assets/audio/"):
        return "arcade_audio"
    if p.startswith("assets/models/"):
        name = p[:-7] if p.endswith(".import") else p
        return "modern_textures" if name.endswith(IMAGE_EXT) else "modern_meshes"
    return "ui_scripts_data"


def source_map(path, files):
    """Imported file in the PCK -> its source, from the .import (remap) files inside the PCK."""
    mapping = {}
    with open(path, "rb") as f:
        for name, offset, size, _ in files:
            if not name.endswith(".import") or size > 65536:
                continue
            f.seek(offset)
            text = f.read(size).decode("utf-8", "replace")
            if "[remap]" not in text:
                raise PckError("%s ist keine Import-Datei – die Dateiversätze des PCK werden falsch gelesen" % name)
            source = name[:-7]
            for m in re.finditer(r'^path(?:\.[A-Za-z0-9_]+)?="res://([^"]+)"', text, re.M):
                mapping[m.group(1)] = source
            m = re.search(r"dest_files=\[([^\]]*)\]", text)
            if m:
                for dest in re.findall(r'"res://([^"]+)"', m.group(1)):
                    mapping[dest] = source
    return mapping


def deflated(data):
    return len(zlib.compress(data, 9))


def analyse(path, with_deflate=True):
    info, files = read_pck(path)
    mapping = source_map(path, files)
    parts = {pid: {"files": 0, "raw": 0, "deflate": 0} for pid, _, _, _ in PARTS}
    rows = []
    with open(path, "rb") as f:
        # the executable around the PCK
        f.seek(0)
        head = f.read(info["start"])
        f.seek(info["end"])
        tail = f.read()
        parts["engine"]["raw"] = len(head) + len(tail)
        parts["engine"]["files"] = 1 if head else 0
        if with_deflate:
            parts["engine"]["deflate"] = (deflated(head) if head else 0) + (deflated(tail) if tail else 0)
        del head
        for name, offset, size, _ in files:
            source = mapping.get(name, name)
            pid = part_of(source)
            comp = 0
            if with_deflate:
                f.seek(offset)
                comp = deflated(f.read(size))
            parts[pid]["files"] += 1
            parts[pid]["raw"] += size
            parts[pid]["deflate"] += comp
            rows.append((size, comp, pid, source, name))
    return info, parts, rows


def gate(total_mb, what, warn_mb, fail_mb):
    """Prints the verdict on the archive size and returns the exit code."""
    line = "%s: %.1f MB – Grenzen: Warnung über %.0f, Abbruch über %.0f, hartes Limit %.0f MB" % (what, total_mb, warn_mb, fail_mb, HARD_MB)
    if total_mb > fail_mb:
        print("==> " + line)
        print("==> ZU GROSS: das Archiv überschreitet die Abbruchgrenze von %.0f MB (Vertrag Regel 6)" % fail_mb)
        return 1
    if total_mb > warn_mb:
        print("==> " + line)
        print("==> WARNUNG: das Archiv liegt über %.0f MB – Texturen, Musik oder Modelle verkleinern, bevor es %.0f MB erreicht" % (warn_mb, fail_mb))
        return 0
    print(line + " – in Ordnung")
    return 0


def main():
    ap = argparse.ArgumentParser(description="Größentabelle und Größengrenze eines Builds", add_help=True)
    ap.add_argument("file", nargs="?", help="exportierte ausführbare Datei oder .pck")
    ap.add_argument("--archive", help="das fertige Archiv (.zip / .tar.gz): seine Größe wird geprüft")
    ap.add_argument("--warn-mb", type=float, default=WARN_MB)
    ap.add_argument("--fail-mb", type=float, default=FAIL_MB)
    ap.add_argument("--no-gate", action="store_true", help="nur berichten, nie mit Fehler enden")
    ap.add_argument("--strict", action="store_true", help="auch ein Teil über seinem Budget ist ein Fehler")
    ap.add_argument("--gate-only", action="store_true", help="keine Tabelle, nur die Archivgröße prüfen")
    ap.add_argument("--no-deflate", action="store_true", help="nur Rohgrößen (schnell, ohne Archiv-Schätzung)")
    ap.add_argument("--top", type=int, default=0, help="die N größten Dateien auflisten")
    ap.add_argument("--tsv", help="alle Dateien als Tabelle schreiben")
    ap.add_argument("--json", help="Ergebnis als JSON schreiben")
    args = ap.parse_args()

    archive_mb = None
    if args.archive:
        if not os.path.isfile(args.archive):
            print("==> Archiv fehlt: %s" % args.archive, file=sys.stderr)
            return 2
        archive_mb = os.path.getsize(args.archive) / MB
    if args.gate_only:
        if archive_mb is None:
            print("==> --gate-only braucht --archive", file=sys.stderr)
            return 2
        code = gate(archive_mb, "Archiv %s (gemessen)" % args.archive, args.warn_mb, args.fail_mb)
        return 0 if args.no_gate else code
    if not args.file:
        ap.print_usage(sys.stderr)
        return 2
    t0 = time.time()
    try:
        info, parts, rows = analyse(args.file, not args.no_deflate)
    except (OSError, PckError, struct.error) as e:
        print("==> %s: %s" % (args.file, e), file=sys.stderr)
        return 2

    print("Größe des Builds %s – %.1f MB, Spieldaten (PCK, Godot %s): %d Dateien" % (
        args.file, info["size"] / MB, info["godot"], info["count"]))
    print("%-32s %8s %10s %14s %10s" % ("Teil", "Dateien", "roh MB", "im Archiv MB", "Budget MB"))
    over = []
    raw_sum = 0
    comp_sum = 0
    for pid, label, budget, tolerance in PARTS:
        p = parts[pid]
        raw_sum += p["raw"]
        comp_sum += p["deflate"]
        comp_mb = p["deflate"] / MB
        status = ""
        if not args.no_deflate and budget is not None and comp_mb > budget * tolerance + 0.005:
            status = "  ÜBER BUDGET"
            over.append(label)
        print("%-32s %8d %10.2f %14s %10s%s" % (
            label, p["files"], p["raw"] / MB, "–" if args.no_deflate else "%.2f" % comp_mb,
            "–" if budget is None else ("%.1f" % budget), status))
    print("%-32s %8d %10.2f %14s %10.1f" % (
        "Summe", sum(parts[pid]["files"] for pid, _, _, _ in PARTS), raw_sum / MB,
        "–" if args.no_deflate else "%.2f" % (comp_sum / MB), TOTAL_BUDGET_MB))
    if not args.no_deflate:
        print("(„im Archiv“ = deflate -9 je Datei, geschätzt; Budgets nach Vertrag §4.11; %.0f s)" % (time.time() - t0))

    if args.top > 0:
        print("Die %d größten Dateien:" % args.top)
        for size, comp, pid, source, name in sorted(rows, reverse=True)[:args.top]:
            print("  %9.2f MB  %-16s %s" % (size / MB, pid, source))
    if args.tsv:
        with open(args.tsv, "w", encoding="utf-8") as out:
            for size, comp, pid, source, name in sorted(rows, reverse=True):
                out.write("%d\t%d\t%s\t%s\t%s\n" % (size, comp, pid, source, name))
    code = 0
    if archive_mb is not None:
        code = gate(archive_mb, "Archiv %s (gemessen)" % args.archive, args.warn_mb, args.fail_mb)
    elif not args.no_deflate:
        code = gate(comp_sum / MB, "Archiv (geschätzt aus der Summe)", args.warn_mb, args.fail_mb)
    if over:
        print("==> Über dem Budget ihres Teils: %s" % ", ".join(over))
        if args.strict:
            code = 1
    if args.json:
        with open(args.json, "w", encoding="utf-8") as out:
            json.dump({"file": args.file, "bytes": info["size"], "godot": info["godot"], "files": info["count"],
                       "parts": {pid: dict(parts[pid], label=label, budget_mb=budget) for pid, label, budget, _ in PARTS},
                       "archive": args.archive, "archive_mb": archive_mb, "estimate_mb": None if args.no_deflate else comp_sum / MB,
                       "over_budget": over, "warn_mb": args.warn_mb, "fail_mb": args.fail_mb}, out, indent=1, ensure_ascii=False)
    return 0 if args.no_gate else code


if __name__ == "__main__":
    sys.exit(main())
