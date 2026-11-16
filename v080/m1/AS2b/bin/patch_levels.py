"""One-off edit of police3d.py: livery bands per level (thin stripes leave the far level)."""
p = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-3/tools/blender/ce3d/police3d.py"
s = open(p).read()
reps = [
    ("""    def row_levels(self, far=False):
        \"\"\"Heights of the livery lines: band edges and the rows of the checks (at the levels that show them).\"\"\"
        out = set()
        for b in self.bands:
            out.update(round(float(v), 5) for v in b["z"])
            if "check" in b and not far:""",
     """    def bands_at(self, level):
        \"\"\"The bands a level shows: the far level leaves out stripes thinner than THIN_FAR_M (a pin stripe of 3 - 7 cm
        is a third of a pixel at 120 m; each of its lines costs a row or a cut along the whole car).\"\"\"
        if level < 2:
            return list(self.bands)
        return [b for b in self.bands if b["z"][1] - b["z"][0] >= THIN_FAR_M]

    def row_levels(self, level):
        \"\"\"Heights of the livery lines of a level: band edges and the rows of the checks where the level shows them.\"\"\"
        out = set()
        for b in self.bands_at(level):
            out.update(round(float(v), 5) for v in b["z"])
            if "check" in b and level < CHECK_FAR_LEVEL:"""),
    ("""        for b in self.bands:
            if "check" in b:
                cw = b["check"][0]
                for k in range(-6, 7):""",
     """        for b in self.bands_at(level):
            if "check" in b:
                cw = b["check"][0]
                for k in range(-6, 7):"""),
    ("""    def _bands(self, t, pal, base_data, i_paint, level):
        if not self.bands:
            return
        lines = set()
        for b in self.bands:
            lines.update(b["z"])
            if "check" in b and level < CHECK_FAR_LEVEL:
                cw, ch, _c2 = b["check"]
                z = b["z"][0] + ch
                while z < b["z"][1] - 1e-4:
                    lines.add(round(z, 5))
                    z += ch
""",
     """    def _bands(self, t, pal, base_data, i_paint, level):
        bands = self.bands_at(level)
        if not bands:
            return
        lines = set(self.row_levels(level))
"""),
    ("""        zlo, zhi = min(b["z"][0] for b in self.bands), max(b["z"][1] for b in self.bands)""",
     """        zlo, zhi = min(b["z"][0] for b in bands), max(b["z"][1] for b in bands)"""),
    ("""        checks = [b for b in self.bands if "check" in b]""",
     """        checks = [b for b in bands if "check" in b]"""),
    ("""        new = t.mat.copy()
        for b in self.bands:""",
     """        new = t.mat.copy()
        for b in bands:"""),
    ("""            segs = _row_segments(ref, pol.row_levels(far=pol.cur_level >= CHECK_FAR_LEVEL))""",
     """            segs = _row_segments(ref, pol.row_levels(pol.cur_level))"""),
    ("""        segs = _row_segments(half(y_ref)[0], pol.row_levels(far=pol.cur_level >= CHECK_FAR_LEVEL))""",
     """        segs = _row_segments(half(y_ref)[0], pol.row_levels(pol.cur_level))"""),
    ("""                _recap(soups[name], pol.row_levels(far=level >= CHECK_FAR_LEVEL), pol.check_x(level))""",
     """                _recap(soups[name], pol.row_levels(level), pol.check_x(level))"""),
    ("""SPLIT_MIN_M = (0.01, 0.04, 0.10)""",
     """SPLIT_MIN_M = (0.01, 0.04, 0.15)"""),
    ("""SPLIT_MIN_M2 = (2.0e-4, 2.0e-3, 1.0e-2)""",
     """SPLIT_MIN_M2 = (2.0e-4, 2.0e-3, 3.0e-2)
THIN_FAR_M = 0.10            # stripes thinner than this (m) are left out at the far level (Police.bands_at)"""),
]
for a, b in reps:
    if a not in s:
        raise SystemExit("missing: " + a[:80])
    s = s.replace(a, b)
open(p, "w").write(s)
print("ok")
