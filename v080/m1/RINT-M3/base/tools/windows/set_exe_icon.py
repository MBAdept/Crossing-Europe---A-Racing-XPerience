#!/usr/bin/env python3
"""Puts the complete program icon into an exported Windows executable of the game.

Why: Godot 4.7's Windows export (application/modify_resources) writes the icon resources itself, but
  * keeps only the frames 16, 32, 48, 64, 128 and 256 px of the .ico – the 24 px frame (taskbar of
    Windows 11 and small icons at 150 % scaling) is dropped,
  * and gives the icon group a broken name (the name offset points into a directory table, so the group
    is called "" instead of "GODOT_ICON", the name of the export template that the engine looks up).
This tool rebuilds the resource section (.rsrc) after the export: every frame of the .ico as RT_ICON and
one icon group RT_GROUP_ICON named GODOT_ICON (as in the original export template); all other resources
(version information, manifest) are kept byte for byte. If the section grows, the sections behind it
(.reloc and Godot's "pck" section with the embedded game data) move back; headers, data directories,
image size and checksum are updated. The embedded PCK finds itself again: Godot locates it through the
"pck" section header and the offsets inside the PCK are relative to its start.

Only Python 3 (standard library) is needed.
Usage: python3 tools/windows/set_exe_icon.py build/CrossingEurope.exe assets/icons/app_icon.ico
"""
import os
import struct
import sys

RT_ICON = 3
RT_GROUP_ICON = 14
GROUP_NAME = "GODOT_ICON"
DIR_RESOURCE = 2
DIR_SECURITY = 4
DIR_DEBUG = 6
PCK_MAGIC = 0x43504447  # "GDPC"


class PEError(Exception):
    pass


def align(value, alignment):
    return (value + alignment - 1) // alignment * alignment


# --- Reading ---------------------------------------------------------------------------------------

class PE:
    """Headers of a PE32+ file and helpers; the file itself is never loaded completely."""

    def __init__(self, f):
        self.f = f
        head = self.read_at(0, 4096)
        if head[:2] != b"MZ":
            raise PEError("keine EXE-Datei (MZ fehlt)")
        self.pe_off = struct.unpack_from("<I", head, 0x3C)[0]
        head = self.read_at(0, self.pe_off + 24 + 0x200)
        if head[self.pe_off:self.pe_off + 4] != b"PE\0\0":
            raise PEError("keine PE-Datei")
        self.coff_off = self.pe_off + 4
        (self.machine, self.n_sections, _, _, _, self.opt_size, _) = struct.unpack_from("<HHIIIHH", head, self.coff_off)
        self.opt_off = self.coff_off + 20
        head = self.read_at(0, self.opt_off + self.opt_size + 40 * self.n_sections)
        self.header = bytearray(head)
        magic = struct.unpack_from("<H", head, self.opt_off)[0]
        if magic != 0x20B:
            raise PEError("keine 64-Bit-PE-Datei (PE32+)")
        self.section_alignment, self.file_alignment = struct.unpack_from("<II", head, self.opt_off + 32)
        self.n_dirs = struct.unpack_from("<I", head, self.opt_off + 108)[0]
        self.dir_off = self.opt_off + 112
        self.sec_off = self.opt_off + self.opt_size
        self.sections = []
        for i in range(self.n_sections):
            o = self.sec_off + 40 * i
            name = head[o:o + 8].rstrip(b"\0").decode("latin-1")
            vsize, va, raw_size, raw_ptr = struct.unpack_from("<IIII", head, o + 8)
            self.sections.append({"index": i, "name": name, "vsize": vsize, "va": va, "raw_size": raw_size, "raw_ptr": raw_ptr})

    def read_at(self, offset, size):
        self.f.seek(offset)
        data = self.f.read(size)
        if len(data) != size:
            raise PEError("Datei zu kurz")
        return data

    def directory(self, index):
        if index >= self.n_dirs:
            return 0, 0
        return struct.unpack_from("<II", self.header, self.dir_off + 8 * index)

    def section_of_rva(self, rva):
        for s in self.sections:
            if s["va"] <= rva < s["va"] + max(s["vsize"], s["raw_size"]):
                return s
        return None


def parse_resources(blob, base_rva):
    """Resource tree of a .rsrc section: [(key, [(key, [(lang, codepage, data)])])] – key is int or str."""

    def name_of(raw):
        if raw & 0x80000000:
            o = raw & 0x7FFFFFFF
            n = struct.unpack_from("<H", blob, o)[0]
            return blob[o + 2:o + 2 + 2 * n].decode("utf-16-le")
        return raw

    def entries(off):
        _, _, _, _, n_named, n_ids = struct.unpack_from("<IIHHHH", blob, off)
        for i in range(n_named + n_ids):
            yield struct.unpack_from("<II", blob, off + 16 + 8 * i)

    def leaf(off):
        rva, size, codepage, _ = struct.unpack_from("<IIII", blob, off)
        start = rva - base_rva
        if start < 0 or start + size > len(blob):
            raise PEError("Ressourcendaten liegen außerhalb von .rsrc")
        return codepage, bytes(blob[start:start + size])

    tree = []
    for t_raw, t_off in entries(0):
        if not t_off & 0x80000000:
            raise PEError("unerwarteter Ressourcenbaum (Typ ohne Unterverzeichnis)")
        names = []
        for n_raw, n_off in entries(t_off & 0x7FFFFFFF):
            if not n_off & 0x80000000:
                raise PEError("unerwarteter Ressourcenbaum (Name ohne Unterverzeichnis)")
            langs = []
            for l_raw, l_off in entries(n_off & 0x7FFFFFFF):
                if l_off & 0x80000000:
                    raise PEError("unerwarteter Ressourcenbaum (vierte Ebene)")
                codepage, data = leaf(l_off)
                langs.append((l_raw, codepage, data))
            names.append((name_of(n_raw), langs))
        tree.append((name_of(t_raw), names))
    return tree


# --- Icon ------------------------------------------------------------------------------------------

def read_ico(path):
    """Frames of an .ico: [(width, height, colors, planes, bpp, data)]."""
    with open(path, "rb") as f:
        data = f.read()
    reserved, kind, count = struct.unpack_from("<HHH", data, 0)
    if reserved != 0 or kind != 1 or count == 0:
        raise PEError("%s ist keine Icon-Datei" % path)
    frames = []
    for i in range(count):
        w, h, colors, _, planes, bpp, size, offset = struct.unpack_from("<BBBBHHII", data, 6 + 16 * i)
        if offset + size > len(data):
            raise PEError("%s: Bild %d unvollständig" % (path, i))
        frames.append((w or 256, h or 256, colors, planes, bpp, data[offset:offset + size]))
    frames.sort(key=lambda fr: (fr[0], fr[4]))
    return frames


def icon_resources(frames, lang):
    """RT_ICON and RT_GROUP_ICON subtrees for the frames."""
    icons = []
    group = bytearray(struct.pack("<HHH", 0, 1, len(frames)))
    for i, (w, h, colors, planes, bpp, data) in enumerate(frames, start=1):
        icons.append((i, [(lang, 0, data)]))
        group += struct.pack("<BBBBHHIH", w % 256, h % 256, colors, 0, planes, bpp, len(data), i)
    return (RT_ICON, icons), (RT_GROUP_ICON, [(GROUP_NAME, [(lang, 0, bytes(group))])])


# --- Writing ---------------------------------------------------------------------------------------

def sort_entries(items):
    """Named entries first (sorted case-insensitively, as Windows searches them), then ids ascending."""
    named = sorted((it for it in items if isinstance(it[0], str)), key=lambda it: it[0].upper())
    ids = sorted((it for it in items if not isinstance(it[0], str)), key=lambda it: it[0])
    return named + ids


def build_resources(tree, base_rva):
    """Serializes a resource tree: directory tables, name strings, data entries, data (8-byte aligned)."""
    tree = sort_entries([(t, sort_entries([(n, sorted(ls, key=lambda l: l[0])) for n, ls in names])) for t, names in tree])
    # 1. directory tables, breadth first: root, one per type, one per name
    level3 = [(n, langs) for _, names in tree for n, langs in names]
    table_off = {}
    off = 0
    order = [("root", 0, tree)] + [("type", i, names) for i, (_, names) in enumerate(tree)] \
        + [("name", i, langs) for i, (_, langs) in enumerate(level3)]
    for kind, i, children in order:
        table_off[(kind, i)] = off
        off += 16 + 8 * len(children)
    # 2. name strings
    strings = {}
    string_blob = bytearray()
    for key in [t for t, _ in tree] + [n for n, _ in level3]:
        if isinstance(key, str) and key not in strings:
            strings[key] = off + len(string_blob)
            enc = key.encode("utf-16-le")
            string_blob += struct.pack("<H", len(enc) // 2) + enc
    off = align(off + len(string_blob), 4)
    # 3. data entries, 4. data
    leaves = [leaf for _, langs in level3 for leaf in langs]
    entries_off = off
    off += 16 * len(leaves)
    data_offs = []
    for _, _, data in leaves:
        off = align(off, 8)
        data_offs.append(off)
        off += len(data)
    out = bytearray(off)

    def put_table(at, children):
        n_named = sum(1 for c in children if isinstance(c[0], str))
        struct.pack_into("<IIHHHH", out, at, 0, 0, 0, 0, n_named, len(children) - n_named)

    def key_field(key):
        return (0x80000000 | strings[key]) if isinstance(key, str) else key

    put_table(table_off[("root", 0)], tree)
    for i, (t, names) in enumerate(tree):
        struct.pack_into("<II", out, 16 + 8 * i, key_field(t), 0x80000000 | table_off[("type", i)])
    name_index = 0
    leaf_index = 0
    for ti, (t, names) in enumerate(tree):
        at = table_off[("type", ti)]
        put_table(at, names)
        for j, (n, langs) in enumerate(names):
            struct.pack_into("<II", out, at + 16 + 8 * j, key_field(n), 0x80000000 | table_off[("name", name_index)])
            at3 = table_off[("name", name_index)]
            put_table(at3, langs)
            for k, (lang, codepage, data) in enumerate(langs):
                e_off = entries_off + 16 * leaf_index
                struct.pack_into("<II", out, at3 + 16 + 8 * k, lang, e_off)
                d_off = data_offs[leaf_index]
                struct.pack_into("<IIII", out, e_off, base_rva + d_off, len(data), codepage, 0)
                out[d_off:d_off + len(data)] = data
                leaf_index += 1
            name_index += 1
    s_start = min(strings.values()) if strings else 0
    out[s_start:s_start + len(string_blob)] = string_blob
    return bytes(out)


def pe_checksum(path, checksum_offset):
    """PE checksum (as CheckSumMappedFile): 16-bit one's complement sum of the file plus its length."""
    total = 0
    size = os.path.getsize(path)
    pos = 0
    with open(path, "rb") as f:
        while True:
            chunk = f.read(64 << 20)
            if not chunk:
                break
            if pos <= checksum_offset < pos + len(chunk):
                b = bytearray(chunk)
                b[checksum_offset - pos:checksum_offset - pos + 4] = b"\0\0\0\0"
                chunk = bytes(b)
            if len(chunk) % 2:
                chunk += b"\0"
            total += sum(memoryview(chunk).cast("H"))
            pos += len(chunk)
    while total >> 16:
        total = (total & 0xFFFF) + (total >> 16)
    return (total + size) & 0xFFFFFFFF


def set_icon(exe_path, ico_path):
    frames = read_ico(ico_path)
    tmp_path = exe_path + ".tmp"
    with open(exe_path, "rb") as f:
        pe = PE(f)
        rsrc_rva, rsrc_size = pe.directory(DIR_RESOURCE)
        if rsrc_rva == 0:
            raise PEError("keine Ressourcen in %s" % exe_path)
        sec_rva, sec_size = pe.directory(DIR_SECURITY)
        if sec_rva or sec_size:
            raise PEError("Datei ist signiert – erst das Icon setzen, dann signieren")
        rsrc = pe.section_of_rva(rsrc_rva)
        if rsrc is None or rsrc["va"] != rsrc_rva:
            raise PEError("Ressourcenverzeichnis liegt nicht am Anfang eines Abschnitts")
        old_blob = pe.read_at(rsrc["raw_ptr"], rsrc["raw_size"])
        tree = parse_resources(old_blob, rsrc["va"])
        langs = [l for t, names in tree if t in (RT_ICON, RT_GROUP_ICON) for _, ls in names for l, _, _ in ls]
        lang = langs[0] if langs else 0
        kept = [(t, names) for t, names in tree if t not in (RT_ICON, RT_GROUP_ICON)]
        new_tree = kept + list(icon_resources(frames, lang))
        new_blob = build_resources(new_tree, rsrc["va"])

        # Sections behind .rsrc (in the file and in memory) move back if .rsrc grows.
        later_raw = {s["index"] for s in pe.sections if s["raw_ptr"] > rsrc["raw_ptr"]}
        later_va = {s["index"] for s in pe.sections if s["va"] > rsrc["va"]}
        if later_raw - later_va:
            raise PEError("Abschnitte hinter .rsrc liegen in Datei und Speicher unterschiedlich")
        old_raw_end = rsrc["raw_ptr"] + rsrc["raw_size"]
        new_raw_size = max(align(len(new_blob), pe.file_alignment), rsrc["raw_size"])
        delta_raw = new_raw_size - rsrc["raw_size"]
        next_va = min((s["va"] for s in pe.sections if s["index"] in later_va), default=None)
        new_end_va = align(rsrc["va"] + len(new_blob), pe.section_alignment)
        delta_va = max(0, new_end_va - next_va) if next_va is not None else 0
        if delta_va % pe.section_alignment or delta_raw % pe.file_alignment:
            raise PEError("Verschiebung nicht ausgerichtet")
        symbols = struct.unpack_from("<I", pe.header, pe.coff_off + 8)[0]
        if symbols and symbols >= old_raw_end and delta_raw:
            raise PEError("COFF-Symboltabelle hinter .rsrc wird nicht unterstützt")

        hdr = pe.header
        # data directories pointing behind .rsrc move with their section (RVAs only – the debug
        # directory would also hold file offsets and must not move)
        for i in range(pe.n_dirs):
            o = pe.dir_off + 8 * i
            rva, size = struct.unpack_from("<II", hdr, o)
            if i == DIR_RESOURCE:
                struct.pack_into("<II", hdr, o, rva, len(new_blob))
            elif rva and next_va is not None and rva >= next_va:
                if i == DIR_DEBUG and (delta_va or delta_raw):
                    raise PEError("Debug-Verzeichnis hinter .rsrc wird nicht unterstützt")
                struct.pack_into("<II", hdr, o, rva + delta_va, size)
            elif rva and rsrc["va"] <= rva < (next_va or rsrc["va"] + rsrc["vsize"]):
                raise PEError("Datenverzeichnis %d zeigt in .rsrc" % i)
        for s in pe.sections:
            if s is rsrc:
                s["vsize"], s["raw_size"] = len(new_blob), new_raw_size
            else:
                if s["index"] in later_va:
                    s["va"] += delta_va
                if s["index"] in later_raw:
                    s["raw_ptr"] += delta_raw
            struct.pack_into("<IIII", hdr, pe.sec_off + 40 * s["index"] + 8, s["vsize"], s["va"], s["raw_size"], s["raw_ptr"])
        last = max(pe.sections, key=lambda s: s["va"])
        size_of_image = align(last["va"] + max(last["vsize"], 1), pe.section_alignment)
        struct.pack_into("<I", hdr, pe.opt_off + 56, size_of_image)
        init_data = struct.unpack_from("<I", hdr, pe.opt_off + 8)[0]
        struct.pack_into("<I", hdr, pe.opt_off + 8, (init_data + delta_raw) & 0xFFFFFFFF)
        checksum_offset = pe.opt_off + 64
        struct.pack_into("<I", hdr, checksum_offset, 0)

        # Write: headers, everything up to .rsrc, new .rsrc, the rest shifted by delta_raw.
        with open(tmp_path, "wb") as out:
            out.write(hdr)
            f.seek(len(hdr))
            copy(f, out, rsrc["raw_ptr"] - len(hdr))
            out.write(new_blob)
            out.write(b"\0" * (new_raw_size - len(new_blob)))
            f.seek(old_raw_end)
            copy(f, out, None)
    checksum = pe_checksum(tmp_path, checksum_offset)
    with open(tmp_path, "r+b") as out:
        out.seek(checksum_offset)
        out.write(struct.pack("<I", checksum))
    verify(tmp_path, frames)
    os.replace(tmp_path, exe_path)
    print("%s: Icon gesetzt (%d Bilder: %s px, Gruppe %s), .rsrc %d → %d Bytes, dahinter %+d Bytes verschoben"
          % (exe_path, len(frames), ", ".join(str(fr[0]) for fr in frames), GROUP_NAME, rsrc_size, len(new_blob), delta_raw))


def copy(src, dst, size):
    remaining = size
    while remaining is None or remaining > 0:
        n = 16 << 20 if remaining is None else min(16 << 20, remaining)
        chunk = src.read(n)
        if not chunk:
            if remaining:
                raise PEError("Datei zu kurz beim Kopieren")
            return
        dst.write(chunk)
        if remaining is not None:
            remaining -= len(chunk)


def verify(path, frames):
    """Re-reads the written file: icons complete, other resources readable, embedded PCK in place."""
    with open(path, "rb") as f:
        pe = PE(f)
        rva, size = pe.directory(DIR_RESOURCE)
        rsrc = pe.section_of_rva(rva)
        tree = dict(parse_resources(pe.read_at(rsrc["raw_ptr"], rsrc["raw_size"]), rsrc["va"]))
        icons = dict(tree.get(RT_ICON, []))
        groups = tree.get(RT_GROUP_ICON, [])
        if len(groups) != 1 or groups[0][0] != GROUP_NAME:
            raise PEError("Icon-Gruppe fehlt nach dem Schreiben")
        grp = groups[0][1][0][2]
        count = struct.unpack_from("<H", grp, 4)[0]
        if count != len(frames):
            raise PEError("Icon-Gruppe hat %d statt %d Bilder" % (count, len(frames)))
        for i in range(count):
            icon_id = struct.unpack_from("<H", grp, 6 + 14 * i + 12)[0]
            if icons[icon_id][0][2] != frames[i][5]:
                raise PEError("Icon %d weicht ab" % icon_id)
        pck = [s for s in pe.sections if s["name"] == "pck"]
        if pck:
            magic = struct.unpack("<I", pe.read_at(pck[0]["raw_ptr"], 4))[0]
            if magic != PCK_MAGIC:
                raise PEError("eingebettetes PCK nach dem Verschieben nicht gefunden")
        f.seek(-4, os.SEEK_END)
        end = f.tell() + 4
        if pck and struct.unpack("<I", f.read(4))[0] != PCK_MAGIC:
            raise PEError("PCK-Marke am Dateiende fehlt")
        if pck and pck[0]["raw_ptr"] + pck[0]["raw_size"] > end:
            raise PEError("Abschnitt pck reicht über das Dateiende hinaus")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    try:
        set_icon(sys.argv[1], sys.argv[2])
    except PEError as e:
        tmp = sys.argv[1] + ".tmp"
        if os.path.exists(tmp):
            os.remove(tmp)
        raise SystemExit("set_exe_icon: %s" % e)
