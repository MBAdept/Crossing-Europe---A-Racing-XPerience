#!/usr/bin/env python3
"""Copies the imported textures (.ctex + .md5) of assets/models whose import is missing in this worktree from the
.godot/imported folder of another worktree (read only), when the source file there is byte-identical (md5 file
names the source md5). Godot re-checks the md5 on the next import anyway."""
import glob
import hashlib
import os
import re
import shutil
import sys

dst_wt, src_wt = sys.argv[1], sys.argv[2]
copied = 0
skipped = []
for f in sorted(glob.glob(os.path.join(dst_wt, "assets", "models", "**", "*.import"), recursive=True)):
    txt = open(f).read()
    m = re.search(r'res://(\.godot/imported/[^"]+)', txt)
    if not m:
        continue
    rel = m.group(1)
    if os.path.exists(os.path.join(dst_wt, rel)):
        continue
    base = rel[: rel.index(".s3tc")] if ".s3tc" in rel else os.path.splitext(rel)[0]
    md5_rel = base + ".md5"
    src_ctex = os.path.join(src_wt, rel)
    src_md5 = os.path.join(src_wt, md5_rel)
    source = f[: -len(".import")]
    if not (os.path.exists(src_ctex) and os.path.exists(src_md5)):
        skipped.append((f, "fehlt in der Quelle"))
        continue
    want = hashlib.md5(open(source, "rb").read()).hexdigest()
    md5_txt = open(src_md5).read()
    if want not in md5_txt:
        skipped.append((f, "Quelle anders"))
        continue
    shutil.copy2(src_ctex, os.path.join(dst_wt, rel))
    shutil.copy2(src_md5, os.path.join(dst_wt, md5_rel))
    copied += 1
print("kopiert:", copied)
for s in skipped:
    print("übersprungen:", s)
