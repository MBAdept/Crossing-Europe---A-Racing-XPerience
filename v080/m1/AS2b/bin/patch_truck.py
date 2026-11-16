"""One-off edit of truck3d.py: liveries of the sprite (box with the side word, curtain sider), cab glass and lamps."""
p = "/home/user/crossing-europe---a-racing-xperience/.claude/worktrees/wf_72970c4d-66e-3/tools/blender/ce3d/truck3d.py"
s = open(p).read()


def rep(a, b, count=1):
    global s
    if s.count(a) != count:
        raise SystemExit("expected %d x: %s (found %d)" % (count, a[:90], s.count(a)))
    s = s.replace(a, b)


# --- module docstring: the liveries
rep('''Flat surfaces carry their markings as geometry cut into them (ce3d.decalgeo, one layer - nothing can flicker
at any distance); parts with depth are real meshes.''',
    '''Flat surfaces carry their markings as geometry cut into them (ce3d.decalgeo, one layer - nothing can flicker
at any distance); parts with depth are real meshes.

Liveries (cesprites.heavy.TRUCK_VARIANTS, AS2b): a box trailer carries the stripe and the word of its variant on both
flanks (white "LOGISTIK", blue "TRANSPORT": glyph outlines of the sprite's font, in the stripe colour paint3); a
curtain sider (red, green: "tarp") has corrugated curtains between the rails, pulled in at 22 straps with buckles.
One model per kind: traffic/truck (white), traffic/truck_transport (blue), traffic/truck_tarp (red, green).''')

# --- the build knows its kind
rep('''    def __init__(self, level):
        from cesprites import materials as M''', '''    def __init__(self, level, tarp=False, word=None):
        from cesprites import materials as M''')
rep('''        self.split = level == 0               # tractor / trailer / wheel nodes; else everything is "body"
        p = self.pal''', '''        self.split = level == 0               # tractor / trailer / wheel nodes; else everything is "body"
        self.tarp = tarp                      # curtain sider (red, green) instead of the box
        self.word = word                      # word on the flanks of the box ("LOGISTIK", "TRANSPORT") or None
        p = self.pal''')
rep('''        self.i_glass = p.add("glass", "glass", dict(color="#10161c", rough=0.03, metal=0.0))''',
    '''        # the traffic cars' glass (traffic3d.TRAFFIC_GLASS): lighter, glossy, a little metallic - the black panes of the
        # cab read as painted (art review of AS1, C4)
        self.i_glass = p.add("glass", "glass", dict(color="#2a343e", rough=0.02, metal=0.25))''')

# --- trailer sides
old_sides = s[s.index("    # --- sides: rails, posts, stripe, emblem, reflective line, marker lamps"):
              s.index('    b.panel(node, b.i_paint, [f["f"], f["t"]])')]
new_sides = '''    # --- sides: rails, posts, stripe and word (box) or curtain with straps (tarp), reflective line, marker lamps
    for sgn, key in ((1, "R"), (-1, "l")):
        frame = [dict(poly=_rect(e, BOX_Z0 + e, TR_LEN - e, 1.32), mat=b.i_alu),
                 dict(poly=_rect(e, 3.90, TR_LEN - e, BOX_Z1 - e), mat=b.i_alu),
                 dict(poly=_rect(e, 1.32, 0.1, 3.90), mat=b.i_alu),
                 dict(poly=_rect(TR_LEN - 0.1, 1.32, TR_LEN - e, 3.90), mat=b.i_alu)]
        lamps = []
        if lv <= 1:
            for i in range(5):
                y = 0.6 + i * 3.0
                lamps.append(dict(poly=_rect(y, BOX_Z0 + 0.03, y + 0.10, BOX_Z0 + 0.085), mat=i_marker))
        tape = dict(poly=_rect(0.16, 1.34, TR_LEN - 0.16, 1.39), mat=i_tape_y)
        if b.tarp:
            _curtain(b, node, sgn, key, frame + lamps, tape)
            continue
        side = [dict(poly=_rect(0.1, 1.55, TR_LEN - 0.1, 1.75), mat=b.i_acc)]
        if lv <= 1 and b.word:
            side += _word_items(b, sgn)
        side += frame + [tape] + lamps
        b.panel(node, b.i_paint, [f[key]], {("side", sgn): side})
'''
s = s.replace(old_sides, new_sides)
rep('''    rear = [dict(poly=_rect(-1.10, 1.55, 1.10, 1.75), mat=b.i_acc)]''',
    '''    rear = [] if b.tarp else [dict(poly=_rect(-1.10, 1.55, 1.10, 1.75), mat=b.i_acc)]''')

# --- helpers: the word, the curtain
helpers = '''
CURTAIN_AMP = 0.014                 # the curtain is pulled in this far at a strap (m)
STRAP_Y0, STRAP_DY, STRAP_N = 0.3, 0.6, 22
STRAP = "#26282b"
WORD_Y, WORD_Z, WORD_SIZE = 6.825, 2.85, 0.62    # cesprites.heavy.build_truck: centre of the side text, its size


def _word_items(b, sgn):
    """The word of the livery on one flank as cut outlines (cesprites.heavy._side_text: the sprite's font and size,
    centred on the trailer, reading from the rear to the front on the right flank). Holes keep what is under them."""
    from .police3d import glyph_outlines
    loops = glyph_outlines(b.rig, b.word, WORD_SIZE, res=2 if b.lv == 0 else 1)
    out = []
    for lp, hole in loops:
        out.append(dict(poly=[(WORD_Y + sgn * x, WORD_Z + y) for (x, y) in lp], mat=None if hole else b.i_acc))
    return sorted(out, key=lambda it: it["mat"] is None)


def _curtain(b, node, sgn, key, frame, tape):
    """Curtain side of one flank: the rails and posts flat (strips of the box face), between them the curtain -
    corrugated at lod0 (pulled in at the straps, out to the rails between them), flat further away - with the
    straps and the reflective line cut in; buckles at the foot of each strap (lod0)."""
    lv = b.lv
    x_face = sgn * W2
    i_strap = b.flat(STRAP, 0.6, 0.0)
    # frame: four strips of the box face
    f = _box_faces(-W2, W2, 0.0, TR_LEN, BOX_Z0, 1.32)[key]
    b.panel(node, b.i_paint, [f], {("side", sgn): [it for it in frame if max(p[1] for p in it["poly"]) <= 1.32 + 1e-6]})
    b.panel(node, b.i_alu, [_box_faces(-W2, W2, 0.0, TR_LEN, 3.90, BOX_Z1)[key]])
    b.panel(node, b.i_alu, [_box_faces(-W2, W2, 0.0, 0.1, 1.32, 3.90)[key],
                            _box_faces(-W2, W2, TR_LEN - 0.1, TR_LEN, 1.32, 3.90)[key]])
    # the curtain
    y0, y1 = 0.1, TR_LEN - 0.1
    if lv == 0:
        ys = sorted(set([y0, y1] + [round(y0 + (y1 - y0) * i / 132, 5) for i in range(133)] +
                        [round(STRAP_Y0 + STRAP_DY * i + d, 5) for i in range(STRAP_N) for d in (-0.0175, 0.0175)]))
        zs = (1.32, 1.34, 1.39, 2.6, 3.90)
    else:
        ys, zs = [y0, y1], (1.32, 3.90)

    def x_at(y):
        if lv > 0:
            return x_face
        u = math.pi * (y - STRAP_Y0) / STRAP_DY
        return sgn * (W2 - 0.002 - CURTAIN_AMP * math.cos(u) ** 2)

    def n_at(y):
        if lv > 0:
            return np.array([float(sgn), 0.0, 0.0])
        u = math.pi * (y - STRAP_Y0) / STRAP_DY
        d = CURTAIN_AMP * math.sin(2.0 * u) * math.pi / STRAP_DY      # d(W2 - amp cos^2)/dy
        n = np.array([float(sgn), -sgn * d, 0.0])
        return n / np.linalg.norm(n)
    pos, nor = [], []
    for ya, yb in zip(ys[:-1], ys[1:]):
        for za, zb in zip(zs[:-1], zs[1:]):
            q = [(x_at(ya), ya, za), (x_at(yb), yb, za), (x_at(yb), yb, zb), (x_at(ya), ya, zb)]
            nq = [n_at(ya), n_at(yb), n_at(yb), n_at(ya)]
            for tri in ((0, 1, 2), (0, 2, 3)):
                pp = np.array([q[i] for i in tri], dtype=np.float64)
                nn = np.array([nq[i] for i in tri], dtype=np.float64)
                if np.cross(pp[1] - pp[0], pp[2] - pp[0]) @ nn.sum(axis=0) < 0.0:
                    pp, nn = pp[::-1], nn[::-1]
                pos.append(pp)
                nor.append(nn)
    t = decalgeo.Tris(np.array(pos), np.array(nor))
    t.mat[:] = b.i_paint
    items = [dict(poly=_rect(STRAP_Y0 + STRAP_DY * i - 0.0175, 1.32, STRAP_Y0 + STRAP_DY * i + 0.0175, 3.90), mat=i_strap)
             for i in range(STRAP_N)]
    items.append(tape)
    t.apply("side", sgn, [dict(poly=it["poly"], mat=it["mat"], rank=r, n_min=0.5) for r, it in enumerate(items)],
            cut=True)
    t.normalize()
    b.panels.setdefault(b.nname(node), []).append(t)
    if lv == 0:
        bm = bmesh.new()
        for i in range(STRAP_N):
            y = STRAP_Y0 + STRAP_DY * i
            xo = sgn * (W2 - CURTAIN_AMP + 0.004)
            b.MU.bm_box(0.022, 0.05, 0.085, (xo, y, 1.42), bm=bm)
        with b.node(node):
            b.obj("buckles", bm, b.mat("buckle", "#3a3c40", 0.4, 0.5))

'''
anchor = "# --- tractor -----------------------------------------------------------------------------------------------"
rep(anchor, helpers.lstrip("\n") + "\n" + anchor)

# --- cab: roof marker lamps on the sun visor, side indicator repeaters
rep('''        if lv <= 1:
            # sun visor: a thin plate sloping forward over the windshield
            y_v = CAB_Y1 - 0.13
            bm = MU.prism([(y_v, 3.045), (y_v + 0.2, 2.985), (y_v + 0.2, 3.03), (y_v, 3.1)], 2.3, plane="YZ", offset=-1.15)
            b.obj("visor", bm, dark)''',
    '''        if lv <= 1:
            # sun visor: a thin plate sloping forward over the windshield
            y_v = CAB_Y1 - 0.13
            bm = MU.prism([(y_v, 3.045), (y_v + 0.2, 2.985), (y_v + 0.2, 3.03), (y_v, 3.1)], 2.3, plane="YZ", offset=-1.15)
            b.obj("visor", bm, dark)
        if lv == 0:
            # five amber marker lamps on the front edge of the visor (lit with the tail lights, no anchors)
            bm = bmesh.new()
            for x in (-0.8, -0.4, 0.0, 0.4, 0.8):
                MU.bm_box(0.09, 0.03, 0.035, (x, CAB_Y1 + 0.075, 3.0), bm=bm)
            b.obj("roofmarkers", bm, b.mat("roofmarker", "#c86a12", 0.2), lamp="-marker:1:" + AMBER)
            # indicator repeaters on the cab sides, behind the doors
            bm = bmesh.new()
            for sx in (-1, 1):
                MU.bm_box(0.012, 0.09, 0.045, (sx * (CAB_W2 + 0.004), CAB_Y0 + 0.32, 1.47), bm=bm)
            b.obj("repeaters", bm, b.mat("repeater", "#c86a12", 0.15), lamp="ind")''')

# --- level and build: the kind of the trailer
rep('''def _level(level, paints):
    from cesprites import meshutil as MU
    b = _Build(level)''', '''def _level(level, paints, tarp=False, word=None):
    from cesprites import meshutil as MU
    b = _Build(level, tarp=tarp, word=word)''')
rep('''    paints = {k: v for k, v in livery(first).items() if k != "metal"}
    sspec = _sprite_spec(spec3d["source"])
    origin = np.array([0.0, L / 2.0, 0.0])''', '''    paints = {k: v for k, v in livery(first).items() if k != "metal"}
    # the kind of the trailer: all sets of one model must agree (a word or a curtain is geometry, not paint)
    kinds = {(bool(heavy.TRUCK_VARIANTS[sid.split("_", 1)[1]]["tarp"]), heavy.TRUCK_VARIANTS[sid.split("_", 1)[1]]["text"])
             for sid in set_ids}
    if len(kinds) != 1:
        raise ValueError("%s: the sets %s are different trailers %s" % (model_id, set_ids, sorted(kinds, key=str)))
    tarp, word = kinds.pop()
    sspec = _sprite_spec(spec3d["source"])
    origin = np.array([0.0, L / 2.0, 0.0])''')
rep('''        b, nodes, pivots, wspec, tr = _level(level, paints)''', '''        b, nodes, pivots, wspec, tr = _level(level, paints, tarp, word)''')
rep('''    b, nodes, _p, _w, _tr = _level(3, paints)''', '''    b, nodes, _p, _w, _tr = _level(3, paints, tarp, word)''')
rep('''    model.stats = dict(build_s=round(time.time() - t0, 2))
    return model''', '''    model.stats = dict(build_s=round(time.time() - t0, 2), tarp=tarp, word=word)
    return model''')
open(p, "w").write(s)
print("ok")
