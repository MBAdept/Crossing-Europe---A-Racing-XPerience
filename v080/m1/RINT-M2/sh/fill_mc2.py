import sys
S = sys.argv[1]
for name, a, b in [
    ("bericht_gates.md", "@@MC2G@@", "**GOLDEN modern: 6 von 6 identisch**, **modern-gles OK** (max. 2/255, PSNR 73,2 dB)"),
    ("bericht_teil6.md", "@@MC2@@", "6 von 6 identisch, GLES OK"),
]:
    p = S + "/" + name
    t = open(p, encoding="utf-8").read()
    assert t.count(a) == 1, a
    t = t.replace(a, b)
    open(p, "w", encoding="utf-8").write(t)
print("ok")
