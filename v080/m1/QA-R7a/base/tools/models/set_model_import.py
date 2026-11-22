#!/usr/bin/env python3
"""Writes the Godot .import files of the model textures (assets/models/**/*.png|*.webp).

Usage (from the repository root; bake_models.gd runs it after every bake):
  python3 tools/models/set_model_import.py [--root assets/models] [--check] [--quiet]
then `godot --headless --path . --import` imports the textures.

Every texture is imported VRAM-compressed (S3TC: BC1 without alpha, BC3 with alpha; compress/mode=2,
high_quality=false) with mipmaps; the importer's 3D detection never runs (it only acts on lossless and
lossy textures; its option detect_3d/compress_to is listed with the default because Godot writes it).
The files are written exactly as Godot 4.7.2 writes them, with a uid derived from the path, so an
import does not change them and they can be committed.
  --check   do not write; exit 1 if a file is missing or differs
"""
import argparse
import hashlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
EXT = (".png", ".webp")

TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid}"
path.s3tc="res://.godot/imported/{name}-{md5}.s3tc.ctex"
metadata={{
"imported_formats": ["s3tc_bptc"],
"vram_texture": true
}}

[deps]

source_file="{res}"
dest_files=["res://.godot/imported/{name}-{md5}.s3tc.ctex"]

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""

# Godot's ResourceUID text encoding: base 34 with the digits a-y, 0-8 (least significant first is NOT used:
# the most significant digit comes first)
_CHARS = "abcdefghijklmnopqrstuvwxy012345678"


def uid_text(res_path):
    """Deterministic uid of a resource path (63 bits of its SHA-1)."""
    n = int.from_bytes(hashlib.sha1(res_path.encode("utf-8")).digest()[:8], "big") & 0x7FFFFFFFFFFFFFFF
    if n == 0:
        n = 1
    out = ""
    while n:
        out = _CHARS[n % 34] + out
        n //= 34
    return "uid://" + out


def import_text(res_path):
    return TEMPLATE.format(uid=uid_text(res_path), name=os.path.basename(res_path),
                           md5=hashlib.md5(res_path.encode("utf-8")).hexdigest(), res=res_path)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=os.path.join(ROOT, "assets", "models"))
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()
    root = os.path.abspath(args.root)
    written = same = bad = 0
    for dp, dn, fn in sorted(os.walk(root)):
        dn.sort()
        for f in sorted(fn):
            if not f.endswith(EXT):
                continue
            p = os.path.join(dp, f)
            rel = os.path.relpath(p, ROOT).replace(os.sep, "/")
            if rel.startswith(".."):
                print("ausserhalb des Projekts:", p)
                bad += 1
                continue
            want = import_text("res://" + rel)
            have = None
            if os.path.exists(p + ".import"):
                with open(p + ".import", encoding="utf-8") as fh:
                    have = fh.read()
            if have == want:
                same += 1
                continue
            if args.check:
                print("%s: %s" % ("fehlt" if have is None else "weicht ab", rel + ".import"))
                bad += 1
                continue
            with open(p + ".import", "w", encoding="utf-8") as fh:
                fh.write(want)
            written += 1
    # .import files without a texture are leftovers
    for dp, dn, fn in sorted(os.walk(root)):
        for f in sorted(fn):
            if f.endswith(".import") and not os.path.exists(os.path.join(dp, f[:-7])):
                if args.check:
                    print("verwaist:", os.path.relpath(os.path.join(dp, f), ROOT))
                    bad += 1
                else:
                    os.remove(os.path.join(dp, f))
    if not args.quiet or bad:
        print("%d .import-Dateien geschrieben, %d unverändert, %d Fehler" % (written, same, bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
