#!/usr/bin/env python3
"""KRITIK-R2-CODE: determinism of the two generators of the change, as audio_qc.py --determinism does it, but only for
vehicle_loops.py and sfx_modern.py: each runs twice with --out into scratch folders; both runs must be byte-identical,
every file must equal the committed file, every manifest entry of the generator must equal the committed entry.
    python3 det.py <tree> <scratch-out>
"""
import hashlib, json, os, subprocess, sys, time

tree, out = sys.argv[1], sys.argv[2]
ASSETS = "assets/audio/modern"
GENS = {"tools/audio/modern/vehicle_loops.py": "vehicle", "tools/audio/modern/sfx_modern.py": "sfx"}


def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for b in iter(lambda: fh.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


ok_all = True
for gen, folder in GENS.items():
    runs = []
    for k in ("a", "b"):
        d = os.path.join(out, os.path.basename(gen).replace(".py", ""), k)
        os.makedirs(d, exist_ok=True)
        t = time.time()
        r = subprocess.run(["nice", "-n", "19", sys.executable, os.path.join(tree, gen), "--out", d], capture_output=True, text=True,
                           cwd=tree)
        print(f"{gen} run {k}: exit {r.returncode} in {time.time() - t:.0f}s", flush=True)
        if r.returncode != 0:
            print(r.stderr[-2000:])
            ok_all = False
        runs.append(os.path.join(d, ASSETS))
    ra, rb = runs
    base = os.path.join(tree, ASSETS)
    diffs = []
    nfiles = 0
    for dirpath, _d, files in os.walk(ra):
        for name in sorted(files):
            pa = os.path.join(dirpath, name)
            rel = os.path.relpath(pa, ra)
            pb = os.path.join(rb, rel)
            nfiles += 1
            if not os.path.exists(pb) or sha(pa) != sha(pb):
                diffs.append(f"{rel}: two runs differ")
                continue
            if name == "manifest.json":
                continue
            pc = os.path.join(base, rel)
            if not os.path.exists(pc):
                diffs.append(f"{rel}: missing in the repository")
            elif sha(pa) != sha(pc):
                diffs.append(f"{rel}: repository file is not the generator's")
    man_c = json.load(open(os.path.join(base, folder, "manifest.json")))["sounds"]
    man_a = json.load(open(os.path.join(ra, folder, "manifest.json")))["sounds"]
    ents = [sid for sid, e in man_c.items() if e.get("generator") == gen]
    for sid in ents:
        if man_a.get(sid) != man_c[sid]:
            diffs.append(f"{folder}/{sid}: manifest entry differs")
    extra = [sid for sid, e in man_a.items() if e.get("generator") == gen and sid not in man_c]
    for sid in extra:
        diffs.append(f"{folder}/{sid}: generator writes an entry the repository lacks")
    # committed files of this generator that the generator does not write any more
    committed_files = set()
    for sid in ents:
        e = man_c[sid]
        committed_files.update(e.get("files") or ([e["file"]] if "file" in e else []))
    written = set(os.listdir(os.path.join(ra, folder)))
    for f in sorted(committed_files - written):
        diffs.append(f"{folder}/{f}: in the manifest, not written by the generator")
    print(f"DET {gen}: {'OK' if not diffs else 'FEHLER'} ({nfiles} files per run, {len(ents)} entries)")
    for dl in diffs[:30]:
        print("   -", dl)
    ok_all = ok_all and not diffs
print("DET ALL", "OK" if ok_all else "FEHLER")
