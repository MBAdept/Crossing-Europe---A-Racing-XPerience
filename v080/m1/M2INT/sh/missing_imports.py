#!/usr/bin/env python3
"""Lists texture imports of assets/models whose imported .ctex does not exist yet (import still to do)."""
import glob
import os
import re
import sys

wt = sys.argv[1] if len(sys.argv) > 1 else "."
imps = sorted(glob.glob(os.path.join(wt, "assets", "models", "**", "*.import"), recursive=True))
missing = []
for f in imps:
    txt = open(f).read()
    m = re.search(r'res://(\.godot/imported/[^"]+)', txt)
    if m and not os.path.exists(os.path.join(wt, m.group(1))):
        missing.append(os.path.relpath(f, wt))
print("imports:", len(imps), "missing:", len(missing))
for f in missing[:60]:
    print("  ", f)
