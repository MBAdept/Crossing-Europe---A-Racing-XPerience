import os, sys, zlib, glob, re
root = sys.argv[1]
tot = {"mesh": [0, 0], "tex": [0, 0]}
rows = []
for d in sorted(glob.glob(os.path.join(root, "assets/models/props/city_*"))):
    name = os.path.basename(d)
    m = [0, 0]; t = [0, 0]
    for f in sorted(os.listdir(d)):
        p = os.path.join(d, f)
        if f.endswith(".res") or f == "model.json":
            b = open(p, "rb").read(); m[0] += len(b); m[1] += len(zlib.compress(b, 9))
        elif f.endswith(".import"):
            txt = open(p).read()
            for dest in re.findall(r'dest_files=\[(.*?)\]', txt):
                for q in re.findall(r'"res://(.*?)"', dest):
                    qp = os.path.join(root, q)
                    if os.path.exists(qp):
                        b = open(qp, "rb").read(); t[0] += len(b); t[1] += len(zlib.compress(b, 9))
    rows.append((name, m, t))
    tot["mesh"][0] += m[0]; tot["mesh"][1] += m[1]; tot["tex"][0] += t[0]; tot["tex"][1] += t[1]
for name, m, t in rows:
    print("%-28s mesh %8d (%8d)  tex %9d (%8d)" % (name, m[0], m[1], t[0], t[1]))
print("TOTAL mesh %.2f MB (archive %.2f MB)  tex %.2f MB (archive %.2f MB)" % (tot["mesh"][0]/1e6, tot["mesh"][1]/1e6, tot["tex"][0]/1e6, tot["tex"][1]/1e6))
