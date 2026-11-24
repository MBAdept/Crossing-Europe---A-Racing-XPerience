#!/usr/bin/env python3
"""Checks an exported Windows executable (PE) of the game – without Windows.

Reports and verifies:
  * machine x86-64, subsystem GUI (no console window), sections incl. Godot's "pck" section,
  * the embedded PCK (header magic "GDPC" at the start of the "pck" section, size, Godot version),
  * the icon group (RT_GROUP_ICON) and its frames (RT_ICON): sizes, bit depth, BMP/PNG,
  * the version resource (VS_VERSIONINFO): numeric file/product version and the strings.
Optional expectations (exit code 1 if one is not met):
  --version=0.5.0         FileVersion/ProductVersion strings and numbers must be 0.5.0.0
  --icon-sizes=16,24,...  these frame sizes must be in the icon group
  --product="…"           ProductName
  --description="…"       FileDescription
Usage: python3 tools/windows/inspect_exe.py build/CrossingEurope.exe [--version=…] [--icon-sizes=…] …
Needs Python 3 with the module pefile (pip install pefile).
"""
import struct
import sys

import pefile

PCK_MAGIC = 0x43504447  # "GDPC"
SUBSYSTEMS = {2: "GUI (Windows)", 3: "Konsole (CUI)"}


def fail(problems, text):
    problems.append(text)
    print("  FEHLER: " + text)


def parse_args(argv):
    path, opts = None, {}
    for a in argv:
        if a.startswith("--") and "=" in a:
            k, v = a[2:].split("=", 1)
            opts[k] = v
        else:
            path = a
    if path is None:
        raise SystemExit(__doc__)
    return path, opts


def pe_checksum(data, checksum_offset):
    """PE checksum as CheckSumMappedFile computes it (16-bit end-around-carry sum plus file length)."""
    total = 0
    step = 64 << 20
    for pos in range(0, len(data), step):
        chunk = bytearray(data[pos:pos + step])
        if pos <= checksum_offset < pos + len(chunk):
            chunk[checksum_offset - pos:checksum_offset - pos + 4] = b"\0\0\0\0"
        if len(chunk) % 2:
            chunk += b"\0"
        total += sum(memoryview(chunk).cast("H"))
    while total >> 16:
        total = (total & 0xFFFF) + (total >> 16)
    return (total + len(data)) & 0xFFFFFFFF


def resource_entries(pe, type_id):
    out = []
    if not hasattr(pe, "DIRECTORY_ENTRY_RESOURCE"):
        return out
    for t in pe.DIRECTORY_ENTRY_RESOURCE.entries:
        if t.id != type_id:
            continue
        for name in t.directory.entries:
            for lang in name.directory.entries:
                key = name.id if name.id is not None else '"%s"' % name.name
                out.append((key, lang.id, lang.data.struct))
    return out


def main():
    path, opts = parse_args(sys.argv[1:])
    problems = []
    pe = pefile.PE(path, fast_load=True)
    pe.parse_data_directories(directories=[pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_RESOURCE"]])
    data = pe.__data__

    print("Datei: %s (%d Bytes)" % (path, len(data)))
    machine = pe.FILE_HEADER.Machine
    print("Maschine: 0x%04x %s" % (machine, "(x86-64)" if machine == 0x8664 else ""))
    if machine != 0x8664:
        fail(problems, "keine x86-64-Datei")
    sub = pe.OPTIONAL_HEADER.Subsystem
    print("Subsystem: %d = %s" % (sub, SUBSYSTEMS.get(sub, "?")))
    if sub != 2:
        fail(problems, "Subsystem ist nicht GUI")

    print("Abschnitte:")
    pck_section = None
    for s in pe.sections:
        name = s.Name.rstrip(b"\0").decode("latin-1")
        print("  %-8s Rohdaten ab 0x%09x, %11d Bytes" % (name, s.PointerToRawData, s.SizeOfRawData))
        if name == "pck":
            pck_section = s

    # Embedded PCK: Godot puts it into the "pck" section (and ends the file with size + magic).
    if pck_section is None:
        fail(problems, "kein Abschnitt \"pck\" – PCK nicht eingebettet")
    else:
        off = pck_section.PointerToRawData
        magic, fmt, major, minor, patch = struct.unpack_from("<IIIII", data, off)
        if magic != PCK_MAGIC:
            fail(problems, "Abschnitt \"pck\" beginnt nicht mit GDPC")
        else:
            print("Eingebettetes PCK: Format %d, Godot %d.%d.%d, %d Bytes ab 0x%x"
                  % (fmt, major, minor, patch, pck_section.SizeOfRawData, off))
        tail_magic = struct.unpack_from("<I", data, len(data) - 4)[0]
        tail_size = struct.unpack_from("<Q", data, len(data) - 12)[0]
        if tail_magic == PCK_MAGIC:
            print("Dateiende: GDPC-Marke, PCK-Größe %d Bytes" % tail_size)

    # Icons
    RT_ICON, RT_GROUP_ICON = 3, 14
    icons = {}
    for key, lang, st in resource_entries(pe, RT_ICON):
        icons[key] = pe.get_data(st.OffsetToData, st.Size)
    groups = resource_entries(pe, RT_GROUP_ICON)
    print("Icon-Gruppen: %d" % len(groups))
    sizes_found = []
    for key, lang, st in groups:
        grp = pe.get_data(st.OffsetToData, st.Size)
        count = struct.unpack_from("<H", grp, 4)[0]
        print("  Gruppe %s (Sprache %d): %d Bilder" % (key, lang, count))
        for i in range(count):
            w, h, colors, _, planes, bpp, size, icon_id = struct.unpack_from("<BBBBHHIH", grp, 6 + 14 * i)
            w, h = w or 256, h or 256
            blob = icons.get(icon_id, b"")
            kind = "PNG" if blob[:8] == b"\x89PNG\r\n\x1a\n" else ("BMP" if blob[:4] == b"\x28\0\0\0" else "?")
            ok = len(blob) == size
            print("    %3d×%-3d %2d bit, %d Ebene(n), %6d Bytes, %s, RT_ICON %d%s"
                  % (w, h, bpp, planes, size, kind, icon_id, "" if ok else " – Daten fehlen/abweichend"))
            if not ok:
                fail(problems, "Icon %d px: RT_ICON %d fehlt oder hat andere Größe" % (w, icon_id))
            sizes_found.append(w)
    if "icon-sizes" in opts:
        want = [int(x) for x in opts["icon-sizes"].split(",") if x]
        missing = [s for s in want if s not in sizes_found]
        if missing:
            fail(problems, "Icon-Größen fehlen: %s" % missing)

    # Version resource
    strings = {}
    if hasattr(pe, "VS_FIXEDFILEINFO") and pe.VS_FIXEDFILEINFO:
        ffi = pe.VS_FIXEDFILEINFO[0]
        fv = (ffi.FileVersionMS >> 16, ffi.FileVersionMS & 0xFFFF, ffi.FileVersionLS >> 16, ffi.FileVersionLS & 0xFFFF)
        pv = (ffi.ProductVersionMS >> 16, ffi.ProductVersionMS & 0xFFFF, ffi.ProductVersionLS >> 16, ffi.ProductVersionLS & 0xFFFF)
        print("VS_FIXEDFILEINFO: Dateiversion %s, Produktversion %s" % (".".join(map(str, fv)), ".".join(map(str, pv))))
    else:
        fv = pv = None
        fail(problems, "keine Versionsressource (VS_VERSIONINFO)")
    for fi in getattr(pe, "FileInfo", []) or []:
        for entry in fi:
            if getattr(entry, "Key", b"") == b"StringFileInfo":
                for table in entry.StringTable:
                    print("StringFileInfo, Tabelle %s:" % table.LangID.decode())
                    for k, v in table.entries.items():
                        k, v = k.decode("utf-8", "replace"), v.decode("utf-8", "replace")
                        strings[k] = v
                        print("  %-17s %s" % (k, v))
            elif getattr(entry, "Key", b"") == b"VarFileInfo":
                for var in entry.Var:
                    for k, v in var.entry.items():
                        print("VarFileInfo: %s = %s" % (k.decode(), v))
    if "version" in opts:
        want = opts["version"].split(".")
        want4 = ".".join((want + ["0", "0", "0", "0"])[:4])
        for k in ("FileVersion", "ProductVersion"):
            if strings.get(k) != want4:
                fail(problems, "%s ist %r statt %r" % (k, strings.get(k), want4))
        if fv is not None and ".".join(map(str, fv)) != want4:
            fail(problems, "numerische Dateiversion %s statt %s" % (".".join(map(str, fv)), want4))
        if pv is not None and ".".join(map(str, pv)) != want4:
            fail(problems, "numerische Produktversion %s statt %s" % (".".join(map(str, pv)), want4))
    if "product" in opts and strings.get("ProductName") != opts["product"]:
        fail(problems, "ProductName ist %r" % strings.get("ProductName"))
    if "description" in opts and strings.get("FileDescription") != opts["description"]:
        fail(problems, "FileDescription ist %r" % strings.get("FileDescription"))

    # PE checksum (Windows checks it only for drivers and system DLLs – informational)
    stored = pe.OPTIONAL_HEADER.CheckSum
    actual = pe_checksum(data, pe.OPTIONAL_HEADER.get_file_offset() + 64)
    print("Prüfsumme im Header: 0x%08x, berechnet 0x%08x (%s)" % (stored, actual, "stimmt" if stored == actual else "veraltet"))

    print("Ergebnis: %s" % ("OK" if not problems else "%d Problem(e)" % len(problems)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
