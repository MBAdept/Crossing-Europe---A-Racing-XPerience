#!/usr/bin/env python3
"""Extract selected files from the PCK embedded in an exported Godot executable.

usage: pck_extract.py <pck_report.py> <executable> <out_dir> <substring>...
Prints the PCK info and every path that contains one of the substrings; writes those files to out_dir.
"""
import importlib.util
import os
import sys

spec = importlib.util.spec_from_file_location("pck_report", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

exe, out_dir, subs = sys.argv[2], sys.argv[3], sys.argv[4:]
info, files = mod.read_pck(exe)
print("INFO", info)
os.makedirs(out_dir, exist_ok=True)
with open(exe, "rb") as f:
    for name, offset, size, flags in files:
        if any(s in name for s in subs):
            f.seek(offset)
            data = f.read(size)
            out = os.path.join(out_dir, name.replace("/", "__"))
            with open(out, "wb") as o:
                o.write(data)
            print("FILE", name, size, "flags", flags, "->", out, "head", data[:16])
