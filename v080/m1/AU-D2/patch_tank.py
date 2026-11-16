import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
rep = [
("""        lead.append(("T", 0, [f"0:4:{N(dm['5'])}:l 4:4:{N(dm['5'] - 1)}:l 8:4:{N(dm['4'])}:l 12:4:{N(dm['3'])}:l",
                              f"0:16:{N(dm['r'])}:B-12"], 0, "soft", 0.9, "lead_syn"))
""", """        sigh = [f"0:4:{N(dm['5'])}:l 4:4:{N(dm['5'] - 1)}:l 8:4:{N(dm['4'])}:l 12:4:{N(dm['3'])}:l",
                f"0:16:{N(dm['r'])}:B-12"]
        lead.append(("T", 0, sigh, 0, "soft", 1.0, "lead_syn"))
        harm.append(("T", 0, sigh, -12, "soft", 0.75, "harm_syn"))
"""),
("""        if k == "T":
            if j == 0 and take < 2:
                return [(0, 20, "open", 0.75, 1, self.iv)]
            return []
        return []
""", """        if k == "T":
            if j == 0:
                return [(0, 20, "open", 0.95 if take < 2 else 0.8, 1, self.iv)]
            return []
        return []
"""),
("""        if k == "T":
            return [(0, bar * 0.98, b.chord, 0.75)]
        return []
""", """        if k == "T":
            return [(0, bar * 0.98, b.chord, 1.0)]
        return []
"""),
("""        if k == "T":
            if j == 0:
                return [(0, 16, CH[self.iv]["root"], 0.55, "d")]
            return [(0, 14, CH[self.Tm]["root"], 0.6, "d")]
""", """        if k == "T":
            if j == 0:
                return [(0, 16, CH[self.iv]["root"], 0.85, "d")]
            return [(0, 14, CH[self.Tm]["root"], 0.85, "d")]
"""),
("""            vel = 0.8 * (1.0 - 0.09 * (i + 6 * b.j))
""", """            vel = 0.95 * (1.0 - 0.09 * (i + 6 * b.j))
"""),
]
for a, b in rep:
    assert a in s, a[:80]
    s = s.replace(a, b, 1)
open(p, 'w', encoding='utf-8').write(s)
print("ok")
