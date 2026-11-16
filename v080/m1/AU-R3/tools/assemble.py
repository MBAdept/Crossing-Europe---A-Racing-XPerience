#!/usr/bin/env python3
"""AU-R3: bericht.md from bericht_src.md + res/tables.md (bridges, towns) + gates.md; writes deliver/AU-R3/bericht.md.
usage: assemble.py <head commit>"""
import os
import sys

S = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/AU-R3"
D = "/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/AU-R3"


def main():
    src = open(f"{S}/bericht_src.md", encoding="utf-8").read()
    tables = open(f"{S}/res/tables.md", encoding="utf-8").read().split("\n")
    i_town = next(i for i, l in enumerate(tables) if l.startswith("| Altstadt | geändert"))
    bridges = "\n".join(tables[:i_town]).strip()
    towns = "\n".join(tables[i_town:]).strip()
    gates = open(f"{S}/gates.md", encoding="utf-8").read().strip() if os.path.exists(f"{S}/gates.md") else "(folgt)"
    out = src.replace("{{HEAD}}", sys.argv[1]).replace("{{BRIDGES}}", bridges).replace("{{TOWNS}}", towns).replace("{{GATES}}", gates)
    assert "{{" not in out, "Platzhalter übrig"
    os.makedirs(D, exist_ok=True)
    open(f"{D}/bericht.md", "w", encoding="utf-8").write(out)
    print("ok", len(out.splitlines()), "Zeilen ->", f"{D}/bericht.md")


if __name__ == "__main__":
    main()
