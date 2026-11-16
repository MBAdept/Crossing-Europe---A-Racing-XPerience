import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()


def rep(old, new, count=1):
    global s
    if s.count(old) != count:
        raise SystemExit("pattern count %d != %d: %r" % (s.count(old), count, old[:70]))
    s = s.replace(old, new)


# --- tyre profile without grooves (3D levels seen from the chase camera) ---------------------------------------
rep('''def _lathe_x(bm, prof, segs, mat_index=0, a0=0.0, a1=360.0, closed=True):''', '''def _tyre_profile_plain(R, r_rim, tw):
    """3D hook: the tyre of _tyre_profile without the grooves - bead, bulging sidewall, rounded shoulder and a
    slightly crowned tread (a third of the triangles)."""
    h = R - r_rim
    half = [(r_rim + 0.006, tw / 2 - 0.014), (r_rim + 0.02, tw / 2 + 0.002), (r_rim + h * 0.45, tw / 2 + 0.008),
            (R - h * 0.22, tw / 2 + 0.004), (R - 0.012, tw / 2 - 0.006), (R - 0.003, tw / 2 - 0.022),
            (R, tw / 2 - 0.045)]
    return [(r, -x) for (r, x) in half] + [(R + 0.001, 0.0)] + list(reversed(half))


def _lathe_x(bm, prof, segs, mat_index=0, a0=0.0, a1=360.0, closed=True):''')

rep('''def wheel_mesh(name, R, r_rim, tw, st, mats, sg=None):
    """One wheel (tyre, rim, spokes, disc, caliper) in local space: axis X, outer face towards +X,
    centre at the origin. mats: dict tyre, rim, rim_dark, disc, caliper. Returns a list of objects.
    sg: segment count at the detail level of a 3D build (None = as designed, the sprite model)."""
    if sg is None:
        def sg(n):
            return n
    objs = []
    # tyre
    bm = bmesh.new()
    _lathe_x(bm, _tyre_profile(R, r_rim, tw), sg(64))''', '''def wheel_mesh(name, R, r_rim, tw, st, mats, sg=None, plain=False):
    """One wheel (tyre, rim, spokes, disc, caliper) in local space: axis X, outer face towards +X,
    centre at the origin. mats: dict tyre, rim, rim_dark, disc, caliper. Returns a list of objects.
    sg: segment count at the detail level of a 3D build (None = as designed, the sprite model).
    plain (3D hook): tyre without grooves, spokes of three sections, no wheel nuts."""
    if sg is None:
        def sg(n):
            return n
    objs = []
    # tyre
    bm = bmesh.new()
    _lathe_x(bm, _tyre_profile_plain(R, r_rim, tw) if plain else _tyre_profile(R, r_rim, tw), sg(64))''')

rep('''    def spoke(angle_deg, wa, wb, ra=r0, rb=r1, bend=0.0, twist=0.0):
        k = 7''', '''    def spoke(angle_deg, wa, wb, ra=r0, rb=r1, bend=0.0, twist=0.0):
        k = 3 if plain else 7''')

rep('''    # wheel nuts
    for i in range(5):
        a = 2 * math.pi * i / 5 + 0.3''', '''    # wheel nuts
    for i in range(0 if plain else 5):
        a = 2 * math.pi * i / 5 + 0.3''')

rep('''        meshes[key] = wheel_mesh(car.name + "_wheel_" + key, R, r_rim, tw, st, mats,
                                 sg=None if car.detail["wheel"] == 1.0 else car.n_wheel)''', '''        meshes[key] = wheel_mesh(car.name + "_wheel_" + key, R, r_rim, tw, st, mats,
                                 sg=None if car.detail["wheel"] == 1.0 else car.n_wheel,
                                 plain=bool(car.detail.get("wheel_plain")))''')

# --- glass: panes with their seal objects and dividers (3D: openings are cut under the panes) -------------------
rep('''    car.patch(poly, "side", seal, offset=0.0012, res=0.012, name="dlo_seal", target=target)
    inner = C.ccw(_inset_poly(poly, seal_w))
    car.patch(inner, "side", gm, offset=0.0022, res=0.012, name="dlo_glass", target=target)
    car.glass_outlines.append(("side", True, inner))
    for (yb, yt, w) in s.get("pillars", []):
        zb = _belt(car, yb) - 0.01
        zt = car.green_half(yt)[1]["zs"] + 0.01
        pp = [(yb - w / 2, zb), (yb + w / 2, zb), (yt + w / 2, zt), (yt - w / 2, zt)]
        car.patch(pp, "side", seal if not trim else trim, offset=0.0032, res=0.01, name="bpillar", target=target)''', '''    panes = []                       # 3D hook: (name, projection, symmetric, glass outline, seal object)
    sob = car.patch(poly, "side", seal, offset=0.0012, res=0.012, name="dlo_seal", target=target)
    inner = C.ccw(_inset_poly(poly, seal_w))
    car.patch(inner, "side", gm, offset=0.0022, res=0.012, name="dlo_glass", target=target)
    car.glass_outlines.append(("side", True, inner))
    panes.append(("dlo", "side", True, inner, sob))
    for (yb, yt, w) in s.get("pillars", []):
        zb = _belt(car, yb) - 0.01
        zt = car.green_half(yt)[1]["zs"] + 0.01
        pp = [(yb - w / 2, zb), (yb + w / 2, zb), (yt + w / 2, zt), (yt - w / 2, zt)]
        car.glass_pillars.append(("side", True, pp))
        car.patch(pp, "side", seal if not trim else trim, offset=0.0032, res=0.01, name="bpillar", target=target)''')

rep('''    car.patch(poly, "top", seal, offset=0.0012, res=0.014, sym=False, name="ws_seal", target=target)
    car.patch(C.ccw(_inset_poly(C.ccw(poly), seal_w)), "top", gm, offset=0.0022, res=0.014, sym=False,
              name="ws_glass", target=target)
    car.glass_outlines.append(("top", False, C.ccw(_inset_poly(C.ccw(poly), seal_w))))''', '''    sob = car.patch(poly, "top", seal, offset=0.0012, res=0.014, sym=False, name="ws_seal", target=target)
    car.patch(C.ccw(_inset_poly(C.ccw(poly), seal_w)), "top", gm, offset=0.0022, res=0.014, sym=False,
              name="ws_glass", target=target)
    car.glass_outlines.append(("top", False, C.ccw(_inset_poly(C.ccw(poly), seal_w))))
    panes.append(("ws", "top", False, C.ccw(_inset_poly(C.ccw(poly), seal_w)), sob))''')

rep('''    car.patch(poly, proj, seal, offset=0.0012, res=0.012, sym=False, name="rw_seal", target=target)
    car.patch(C.ccw(_inset_poly(poly, seal_w)), proj, gm, offset=0.0022, res=0.012, sym=False, name="rw_glass",
              target=target)
    car.glass_outlines.append((proj, False, C.ccw(_inset_poly(poly, seal_w))))
    return gm''', '''    sob = car.patch(poly, proj, seal, offset=0.0012, res=0.012, sym=False, name="rw_seal", target=target)
    car.patch(C.ccw(_inset_poly(poly, seal_w)), proj, gm, offset=0.0022, res=0.012, sym=False, name="rw_glass",
              target=target)
    car.glass_outlines.append((proj, False, C.ccw(_inset_poly(poly, seal_w))))
    panes.append(("rw", proj, False, C.ccw(_inset_poly(poly, seal_w)), sob))
    car.panes = panes
    return gm''')

# --- lamps: channels and housing of the real-time models --------------------------------------------------------
rep('''_LAMP3D = {"reverse": "reverse", "indicator": "ind", "white": "drl", ("head", "dark"): "head"}''',
    '''_LAMP3D = {"reverse": "reverse", "indicator": "ind", "white": "drl", ("head", "dark"): "head"}
# ... and of the parts of a tail lamp when the build has the 3D lamp parts (detail "extras"): the lamp body glows
# with the tail lights and lights up fully when braking, light guides are the tail-light signature, brake segments
# only brake. Parts of other lamps (reflectors, fog lamps) keep the channel their emission gives them.
_LAMP3D_TAIL = {"tail": "tail_brake:0.5", "guide": "tail", "brake": "brake"}
_TAIL_TAGS = ("tail", "bar", "ring")''')

rep('''    hm = M.basic(car.name + "_housing_" + tag, spec.get("housing", "#b9b3b2"), rough=0.45, metal=0.0, coat=0.2)
    car.patch(spec["outline"], proj, hm, offset=0.0015, res=res, sym=sym, name=tag + "_housing", target=tgt)
    for i, part in enumerate(spec.get("parts", [])):
        kind = part["kind"]
        mat = part_mat(car, kind, part)
        off = part.get("offset", _OFF[kind])
        nm = "%s_%s%d" % (tag, kind, i)''', '''    extras = bool(car.detail["extras"])
    is_tail = extras and any(tag.startswith(t) for t in _TAIL_TAGS)
    housing = spec.get("housing", "#b9b3b2")
    if is_tail:
        # 3D: the lens is nearly clear (the lamp parts carry the red) - a dark housing instead of the pale
        # one that only showed through the red lens of the sprite
        housing = spec.get("housing3d", "#2a0808")
    hm = M.basic(car.name + "_housing_" + tag, housing, rough=0.45, metal=0.0, coat=0.2)
    car.patch(spec["outline"], proj, hm, offset=0.0015, res=res, sym=sym, name=tag + "_housing", target=tgt)
    for i, part in enumerate(spec.get("parts", [])):
        kind = part["kind"]
        mat = part_mat(car, kind, part)
        off = part.get("offset", _OFF[kind])
        nm = "%s_%s%d" % (tag, kind, i)
        lamp3d = part.get("lamp", _LAMP3D.get((tag, kind), _LAMP3D.get(kind)))
        if is_tail and "lamp" not in part and kind in _LAMP3D_TAIL:
            lamp3d = _LAMP3D_TAIL[kind]''')

rep('''        MU.tag(pob, lamp=part.get("lamp", _LAMP3D.get((tag, kind), _LAMP3D.get(kind))))
    lenses = spec.get("lenses")''', '''        MU.tag(pob, lamp=lamp3d)
    lenses = spec.get("lenses")''')

open(p, 'w', encoding='utf-8').write(s)
print("cardetail patched")
