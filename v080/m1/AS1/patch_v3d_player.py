import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()


def rep(old, new, count=1):
    global s
    if s.count(old) != count:
        raise SystemExit("pattern count %d != %d: %r" % (s.count(old), count, old[:70]))
    s = s.replace(old, new)


rep('''from . import core, decalgeo, roles
from . import lod as LOD''', '''from . import core, decalgeo, interior3d, roles
from . import lod as LOD''')

a = s.index("PLAYER_OVERRIDES = {")
b = s.index("def _player_shadow(spec3d):")
new = '''PLAYER_OVERRIDES = {
    # procedural grille shaders (slats / honeycomb): a dark flat stand-in under the bars of the 3D build
    "proc:*": dict(role="flat", color="#0a0a0b", rough=0.55, metal=0.2),
    # paint: glossier than the sprite material - the real-time paint has no clear-coat reflection of the sky
    "paint:*": dict(rough=0.2),
}
# look of the glazing and of the lamp lenses (class glass): opacity of the tinted panes over the cabin, of the
# coloured lenses (the lamp parts under them carry the colour and the light) and of clear headlight lenses
PLAYER_GLASS = dict(glass_opacity=0.36, lens_opacity=0.10, clear_lens_opacity=0.08)
GLASS_OVERLAP_M = 0.008        # the panes overlap the edge of their opening by this much (the black band)
LINER = dict(color="#232427", rough=0.85)


def _shift(outline, proj, dy):
    """Outline of the build space (y = 0 at the rear bumper) in root space (car centred)."""
    if proj == "side":
        return [(p[0] + dy, p[1]) for p in outline]
    if proj == "top":
        return [(p[0], p[1] + dy) for p in outline]
    return list(outline)


def _open_cabin(car, lay, soups):
    """Transparent glazing needs openings: cuts the outline of every pane (inside its black band) out of the
    greenhouse and out of the seal patch under the glass, opens the deck of the lower body under the greenhouse
    and removes the floor of the greenhouse loft. Returns the triangles of the lining (pos, nor): the remaining
    greenhouse seen from inside."""
    by_name = {s.name: s for s in soups}
    dy = -car.L / 2.0
    pillars = [(proj, [decalgeo.inset(_shift(o, proj, dy), 0.004)]) for (proj, _sym, o) in car.glass_pillars]
    green = by_name[car.green.name]
    stats = dict(removed=0)

    def cut(soup, proj, signs, hole):
        keeps = [k for (pp, ks) in pillars if pp == proj for k in ks]
        for sgn in signs:
            pos, nor, mat, n = decalgeo.cut_holes(soup.pos, soup.nor, soup.mi, proj, sgn, [hole], keeps)
            soup.pos, soup.nor, soup.mi, soup.n = pos, nor, mat, pos.shape[0]
            stats["removed"] += n
    for (_name, proj, sym, outline, seal_ob) in car.panes:
        hole = decalgeo.inset(_shift(outline, proj, dy), GLASS_OVERLAP_M)
        signs = (1, -1) if (sym and proj == "side") else (1,)
        cut(green, proj, signs, hole)
        if seal_ob is not None and seal_ob.name in by_name:
            cut(by_name[seal_ob.name], proj, signs, hole)
    # floor of the greenhouse loft (lies inside the body): faces looking down
    fn = np.cross(green.pos[:, 1] - green.pos[:, 0], green.pos[:, 2] - green.pos[:, 0])
    fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
    keep = fn[:, 2] > -0.5
    green.pos, green.nor, green.mi = green.pos[keep], green.nor[keep], green.mi[keep]
    green.n = green.pos.shape[0]
    # deck of the lower body under the greenhouse
    body = by_name[car.body.name]
    hole = _shift(interior3d.deck_opening(car, lay), "top", dy)
    pos, nor, mat, n = decalgeo.cut_holes(body.pos, body.nor, body.mi, "top", 1, [hole], n_min=0.3)
    body.pos, body.nor, body.mi, body.n = pos, nor, mat, pos.shape[0]
    stats["removed"] += n
    return green.pos[:, ::-1, :].copy(), -green.nor[:, ::-1, :], stats


def _player_level(spec3d, level):
    from cesprites import meshutil as MU
    from cesprites import player_cars
    from cesprites import rig as R
    sspec = _sprite_spec(spec3d["source"])
    params = dict(sspec["params"])
    params["detail"] = dict(LOD.PLAYER_DETAIL[level], extras=True)
    rig = R.Rig(quick=True)
    MU.tagging(True)
    try:
        info = player_cars.build(rig, params)
        car = info["car"]
        lay = interior3d.build_interior(car, fine=(level == "show"))
    finally:
        MU.tagging(False)
    objs = core.model_objects(rig)
    soups = core.soups_of(objs)
    lin_pos, lin_nor, cut_stats = _open_cabin(car, lay, soups)
    over = dict(PLAYER_OVERRIDES)
    over.update(spec3d.get("overrides", {}))
    tr = roles.Translator(overrides=over, default_paint={"paint": params["paint"]},
                          glass_opacity=spec3d.get("glass_opacity", PLAYER_GLASS["glass_opacity"]),
                          lens_opacity=PLAYER_GLASS["lens_opacity"], clear_lens_opacity=PLAYER_GLASS["clear_lens_opacity"])
    nodes = {}
    pivots = {}
    for s in soups:
        if s.n == 0:
            continue
        node = roles.node_of(s.ob)
        if node.startswith("wheel_"):
            mw = s.ob.matrix_world
            pivots[node] = np.array([mw[0][3], mw[1][3], mw[2][3]], dtype=np.float64)
        _add_soup(nodes, tr, s, node)
    # lining of the greenhouse: the cut loft seen from inside
    col = np.empty(4, dtype=np.uint8)
    col[:3] = core.srgb8(core.hex_to_lin(LINER["color"]))
    col[3] = 255
    nodes["body"].add("vpbr", lin_pos, lin_nor, col, (LINER["rough"], 0.0), roles.NO_LAMP)
    info["cabin"] = dict(lining_tris=int(lin_pos.shape[0]), removed=cut_stats["removed"])
    return car, info, params, nodes, pivots, tr


'''
s = s[:a] + new + s[b:]
open(p, 'w', encoding='utf-8').write(s)
print("vehicles3d player patched")
