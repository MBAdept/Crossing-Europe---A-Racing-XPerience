from patchlib import patch

patch("tools/blender/ce3d/decalgeo.py", [
    ('''def _window_items(w, pal, seal, glass):
    """Window seals and glass of materials.window_masks as items {(proj, sign): [item]}."""
    groups = {}
    fr = w.get("frame", 0.016)
    nx_side = w.get("side_nx", 0.45)
    for poly in w.get("side_frames", w.get("side", [])):
        for sgn in (1, -1):
            groups.setdefault(("side", sgn), []).append(dict(poly=[tuple(p) for p in poly], mat=seal, n_min=nx_side))
    for poly in w.get("side", []):
        for sgn in (1, -1):
            groups.setdefault(("side", sgn), []).append(dict(poly=inset([tuple(p) for p in poly], fr), mat=glass,
                                                             n_min=nx_side))''',
     '''def _window_items(w, pal, seal, glass, seals=True):
    """Window seals and glass of materials.window_masks as items {(proj, sign): [item]}.
    seals=False (far level): the panes fill their frames, no seal polygons."""
    groups = {}
    fr = w.get("frame", 0.016)
    nx_side = w.get("side_nx", 0.45)
    if seals:
        for poly in w.get("side_frames", w.get("side", [])):
            for sgn in (1, -1):
                groups.setdefault(("side", sgn), []).append(dict(poly=[tuple(p) for p in poly], mat=seal,
                                                                 n_min=nx_side))
    for poly in w.get("side", []):
        for sgn in (1, -1):
            groups.setdefault(("side", sgn), []).append(dict(
                poly=inset([tuple(p) for p in poly], fr) if seals else [tuple(p) for p in poly], mat=glass,
                n_min=nx_side))'''),
    ('''        n_z = 6
        zs = [z0 + (z1 - z0) * i / n_z for i in range(n_z + 1)]
        outer = [(hw(z), z) for z in zs] + [(-hw(z), z) for z in reversed(zs)]
        zs2 = [z0 + fr + (z1 - z0 - 2 * fr) * i / n_z for i in range(n_z + 1)]
        inner = [(hw(z, fr), z) for z in zs2] + [(-hw(z, fr), z) for z in reversed(zs2)]
        g = groups.setdefault((key, 1), [])
        g.append(dict(poly=outer, mat=seal, n_min=0.05, y_range=(sp["y"][0], sp["y"][1]), nx_max=nx_side))
        g.append(dict(poly=inner, mat=glass, n_min=0.05, y_range=(sp["y"][0] + fr, sp["y"][1] - fr), nx_max=nx_side))
    return groups''',
     '''        n_z = 1                         # the sides of the pane are straight lines in this projection
        zs = [z0 + (z1 - z0) * i / n_z for i in range(n_z + 1)]
        outer = [(hw(z), z) for z in zs] + [(-hw(z), z) for z in reversed(zs)]
        zs2 = [z0 + fr + (z1 - z0 - 2 * fr) * i / n_z for i in range(n_z + 1)]
        inner = [(hw(z, fr), z) for z in zs2] + [(-hw(z, fr), z) for z in reversed(zs2)]
        g = groups.setdefault((key, 1), [])
        if seals:
            g.append(dict(poly=outer, mat=seal, n_min=0.05, y_range=(sp["y"][0], sp["y"][1]), nx_max=nx_side))
            g.append(dict(poly=inner, mat=glass, n_min=0.05, y_range=(sp["y"][0] + fr, sp["y"][1] - fr),
                          nx_max=nx_side))
        else:
            g.append(dict(poly=outer, mat=glass, n_min=0.05, y_range=(sp["y"][0], sp["y"][1]), nx_max=nx_side))
    return groups'''),
    ('''def car_surfaces(car, soups, cut=True, small=True):
    """Cuts (or paints) the decals of a built vehicles.Car into its body lofts.
    soups: {object name: core.Soup} of the lower body, greenhouse and bumpers.
    Returns (Palette, {object name: Tris}, stats)."""''',
     '''def car_surfaces(car, soups, cut=True, level=0):
    """Cuts (or paints) the decals of a built vehicles.Car into its body lofts.
    soups: {object name: core.Soup} of the lower body, greenhouse and bumpers.
    level: 0 = every decal (lod0); 1 = no seams, handles and other small parts (lod1); 2 = only lamps,
    plates and the panes without their seals (lod2).
    Returns (Palette, {object name: Tris}, stats)."""'''),
    ('''    def small_filter(decals):
        if small:
            return decals
        # far level: only what is still visible - lamps, plates, big dark areas
        keep = []
        for dec in decals:
            polys = dec["poly"] if isinstance(dec["poly"][0][0], (list, tuple)) else [dec["poly"]]
            size = max(max(p[0] for p in polys[0]) - min(p[0] for p in polys[0]),
                       max(p[1] for p in polys[0]) - min(p[1] for p in polys[0]))
            if dec.get("lamp") or dec.get("emit") or size > 0.2:
                keep.append(dec)
        return keep''',
     '''    def small_filter(decals):
        if level == 0:
            return decals
        # farther levels: only what is still visible - lamps, plates, big dark areas (level 1)
        keep = []
        for dec in decals:
            polys = dec["poly"] if isinstance(dec["poly"][0][0], (list, tuple)) else [dec["poly"]]
            size = max(max(p[0] for p in polys[0]) - min(p[0] for p in polys[0]),
                       max(p[1] for p in polys[0]) - min(p[1] for p in polys[0]))
            if dec.get("lamp") or dec.get("emit") or (level == 1 and size > 0.2):
                if level == 2 and dec.get("inset"):
                    dec = dict(dec)
                    dec.pop("inset")            # the lamp fills its (dropped) black outline
                keep.append(dec)
        return keep'''),
    ('''    run(t, _window_items(car.windows(), pal, seal, glass))''',
     '''    run(t, _window_items(car.windows(), pal, seal, glass, seals=level < 2))'''),
])

patch("tools/blender/ce3d/vehicles3d.py", [
    ('''    pal, tris, stats = decalgeo.car_surfaces(car, {s.name: s for s in soups}, cut=True, small=level == "lod0")''',
     '''    pal, tris, stats = decalgeo.car_surfaces(car, {s.name: s for s in soups}, cut=True,
                                             level={"lod0": 0, "lod1": 1, "lod2": 2}[level])'''),
])

patch("tools/blender/ce3d/lod.py", [
    ('''    "lod0": dict(subsurf=0, ring=2, step=1.6, wheel=0.8),''', '''    "lod0": dict(subsurf=0, ring=2, step=2.0, wheel=0.65),'''),
    ('''    "lod1": dict(subsurf=0, ring=1, step=2.5, wheel=0.45, bevel=False, small=False),''',
     '''    "lod1": dict(subsurf=0, ring=1, step=2.5, wheel=0.45, bevel=False, small=False),'''),
    ('''    "lod2": dict(subsurf=0, ring=0, step=5.0, wheel=0.3, bevel=False, mirrors=False, small=False),
    "shadow": dict(subsurf=0, ring=0, step=5.0, wheel=0.3, bevel=False, mirrors=False, small=False),''',
     '''    "lod2": dict(subsurf=0, ring=0, step=5.0, wheel=0.2, bevel=False, mirrors=False, small=False),
    "shadow": dict(subsurf=0, ring=0, step=5.0, wheel=0.2, bevel=False, mirrors=False, small=False),'''),
])
