#!/usr/bin/env python3
"""QA-R7c: assembles deliver/QA-R7c/bericht.md from the parts."""
S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/QA-R7c/"
OUT = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/QA-R7c/bericht.md"
parts = ["bericht_teil_kopf.md", "bericht_teil_kurz.md", "bericht_teil_umfang.md", "bericht_teil_gates.md", "bericht_teil_mut.md", "bericht_teil_render_mut.md",
         "bericht_teil_code.md", "bericht_teil_bilder_kopf.md", "#### 5.1 Je Ort (angesehen)", "look_notes.md", "bericht_teil_fern.md",
         "bericht_teil_perf.md", "bericht_teil_befunde.md", "bericht_teil_vertrag.md", "bericht_teil_ok.md", "bericht_teil_naechste.md",
         "bericht_teil_lieferung.md"]
out = []
for p in parts:
    if p.startswith("#"):
        out.append(p.replace("####", "###") + "\n")
        continue
    out.append(open(S + p).read().rstrip() + "\n")
open(OUT, "w").write("\n".join(out))
print(OUT, sum(x.count("\n") for x in out), "Zeilen")
