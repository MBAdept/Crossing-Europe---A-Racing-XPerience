

# --- lattice models (AS1b): the power pylon as cut-out panels ------------------------------------------------------
#
#   lattice    the frame of the generator (props_road.PYLON_LOG: levels, half widths, arms, insulators) as flat
#              panels whose bracing is DRAWN into one RGBA atlas (class baked_cutout, alpha scissor 0.5): a tower
#              face per section, the bottom and the two sloped sides of every arm, the earth-wire peak as two
#              crossed panels, the insulator strings as hexagonal prisms. A member of 9 cm would be 0.6 px at
#              100 m as a beam (it shimmers and breaks up); drawn into the atlas it keeps a mipmap-safe alpha:
#              members are at least LATTICE_MIN_PX wide and every transparent texel near a member gets the halo
#              alpha 0.33 - below the scissor at full size (with BC3's quantisation margin), but in the averaged
#              texels of coarser mipmaps it keeps a member visible while its share is >= 25 % instead of 50 %.
#              The four faces of a tower section share one picture (the tower is square). One draw call.

LATTICE_SCISSOR = 0.5         # baked.gdshader, CE_CUTOUT
LATTICE_HALO = 0.33           # < 0.5 - 0.07 (BC3 alpha quantisation)
LATTICE_MIN_PX = 2.5          # narrowest member in the atlas (texels)


def _lattice_panels(lg):
    """Panels of the pylon: [dict(key, poly (2D, metres), members [(a, b, width)], frame (origin, ex, ey) list of
    placements, colour)]. 2D coordinates are the panel's own (u across, v up), the frame places them in 3D."""
    levels, half = lg["levels"], lg["half"]
    bw, cw, lw = lg["brace_w"], lg["chord_w"], lg["leg_w"]
    panels = []
    # tower faces: one picture per section, four placements (front, back, left, right)
    for i in range(len(levels) - 1):
        z0, z1, h0, h1 = levels[i], levels[i + 1], half[i], half[i + 1]
        m = lw * 0.5
        poly = [(-h0 - m, z0), (h0 + m, z0), (h1 + m, z1), (-h1 - m, z1)]
        members = [((-h0, z0), (h1, z1), bw), ((h0, z0), (-h1, z1), bw), ((-h1, z1), (h1, z1), cw),
                   ((-h0, z0), (-h1, z1), lw), ((h0, z0), (h1, z1), lw)]
        if i == 0:
            members.append(((-h0, z0), (h0, z0), cw))
        place = []
        for (nx, ny) in ((0.0, -1.0), (0.0, 1.0), (-1.0, 0.0), (1.0, 0.0)):
            # u runs to the right as seen from outside; the plane passes through the leg line (tapers with z)
            n3 = np.array([nx, ny, 0.0])
            place.append(dict(normal=n3, ex=np.cross(-n3, np.array([0.0, 0.0, 1.0]))))
        panels.append(dict(key="tower%d" % i, poly=poly, members=members, tower=place, section=(z0, z1, h0, h1)))
    # arms: bottom (horizontal) and the two sloped sides, one picture each per level, mirrored for the other side
    rise, ry, ty = lg["arm_rise"], lg["arm_root_y"], lg["arm_tip_y"]
    hz = dict((round(z, 2), h) for (z, h) in lg["half_at"])
    for (z, span) in lg["arms"]:
        h_root = hz[round(z, 2)]
        h_top = hz[round(z + rise, 2)]
        length = span - h_root
        aw = lg["arm_w"]
        # bottom: u along the arm (0 at the tower), v across (y)
        poly = [(0.0, -ry - aw), (length + aw, -ty - aw), (length + aw, ty + aw), (0.0, ry + aw)]
        members = [((0.0, -ry), (length, -ty), aw), ((0.0, ry), (length, ty), aw)]
        for t in (0.35, 0.7):
            yy = ry + (ty - ry) * t
            members.append(((length * t, -yy), (length * t, yy), 0.07))
        prev = (0.0, -ry)
        for t in (0.35, 0.7, 1.0):
            yy = ry + (ty - ry) * t
            members.append((prev, (length * t, yy if prev[1] < 0 else -yy), 0.07))
            prev = (length * t, yy if prev[1] < 0 else -yy)
        panels.append(dict(key="arm_bottom_%d" % int(z), poly=poly, members=members, arm=(z, span, h_root, "bottom")))
        # side: u along the arm from the tower, v up; corners root-bottom (0, 0), tip (L, 0), root-top (h_top - h_root, rise)
        du = h_top - h_root
        poly = [(-aw, -aw), (length + aw, -aw), (du, rise + aw), (du - aw, rise + aw)]
        members = [((0.0, 0.0), (length, 0.0), aw), ((du, rise), (length, 0.0), aw), ((0.0, 0.0), (du, rise), aw)]
        for t in (0.3, 0.6):
            members.append(((length * t * 0.95, 0.0), (du + (length - du) * (t + 0.18), rise * (1.0 - t - 0.18)), 0.06))
        panels.append(dict(key="arm_side_%d" % int(z), poly=poly, members=members, arm=(z, span, h_root, "side"),
                           side_geo=(du, rise, length)))
    # earth-wire peak: two crossed triangles
    (a, b, c) = lg["peak"]
    pw = lg["peak_w"]
    poly = [(a[0] - pw, a[2] - pw), (b[0] + pw, b[2] - pw), (c[0] + pw, c[2] + pw), (c[0] - pw, c[2] + pw)]
    members = [((a[0], a[2]), (c[0], c[2]), pw), ((b[0], b[2]), (c[0], c[2]), pw), ((a[0], a[2]), (b[0], b[2]), pw)]
    panels.append(dict(key="peak", poly=poly, members=members, peak=True))
    # insulator picture: discs along the string
    L = lg["ins_len"]
    poly = [(-0.17, 0.0), (0.17, 0.0), (0.17, L), (-0.17, L)]
    panels.append(dict(key="insulator", poly=poly, members=[], solid=True, insulator=L))
    return panels


def _lattice_atlas(panels, size, ppm, colour, ins_colour):
    """Draws the panels into an RGBA atlas (PIL, 4x supersampled). Returns (image, {key: (x0, y0, umin, vmax)}):
    a 2D point (u, v) of a panel lies at texel (x0 + (u - umin) * ppm, y0 + (vmax - v) * ppm)."""
    from PIL import Image, ImageDraw
    ss = 4
    W, H = size
    # shelf packing, tallest first
    boxes = []
    for p in panels:
        us = [q[0] for q in p["poly"]]
        vs = [q[1] for q in p["poly"]]
        boxes.append((p["key"], min(us), max(us), min(vs), max(vs)))
    order = sorted(range(len(boxes)), key=lambda i: (-(boxes[i][4] - boxes[i][3]), boxes[i][0]))
    pad = 6
    x = y = pad
    row_h = 0
    place = {}
    for i in order:
        key, u0, u1, v0, v1 = boxes[i]
        w = int(math.ceil((u1 - u0) * ppm)) + 2
        h = int(math.ceil((v1 - v0) * ppm)) + 2
        if x + w + pad > W:
            x = pad
            y += row_h + pad
            row_h = 0
        if y + h + pad > H:
            raise RuntimeError("lattice atlas %dx%d too small at %.1f px/m" % (W, H, ppm))
        place[key] = (x + 1, y + 1, u0, v1)
        x += w + pad
        row_h = max(row_h, h)
    img = Image.new("RGBA", (W * ss, H * ss), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    col = tuple(int(c) for c in core.srgb8(core.hex_to_lin(colour)))
    icol = tuple(int(c) for c in core.srgb8(core.hex_to_lin(ins_colour)))
    for p in panels:
        x0, y0, umin, vmax = place[p["key"]]

        def tx(q, _x0=x0, _y0=y0, _umin=umin, _vmax=vmax):
            return ((_x0 + (q[0] - _umin) * ppm) * ss, (_y0 + (_vmax - q[1]) * ppm) * ss)
        if p.get("solid"):
            pts = [tx(q) for q in p["poly"]]
            dr.polygon(pts, fill=icol + (255,))
            L = p["insulator"]
            n = 8
            for k in range(n):
                # darker rims of the discs
                vv = 0.25 + (L - 0.4) * k / (n - 1)
                a = tx((-0.17, vv))
                b = tx((0.17, vv + 0.06))
                dr.rectangle([a[0], b[1], b[0], a[1]], fill=tuple(int(c * 0.6) for c in icol) + (255,))
            continue
        for (a, b, w) in p["members"]:
            wp = max(w * ppm, LATTICE_MIN_PX) * ss
            pa, pb = tx(a), tx(b)
            d = np.array(pb) - np.array(pa)
            ln = float(np.linalg.norm(d))
            if ln < 1e-6:
                continue
            nrm = np.array([-d[1], d[0]]) / ln * wp * 0.5
            ext = d / ln * wp * 0.5
            quad = [tuple(np.array(pa) - ext + nrm), tuple(np.array(pb) + ext + nrm),
                    tuple(np.array(pb) + ext - nrm), tuple(np.array(pa) - ext - nrm)]
            # lighter towards the top of the member's own width: a little relief
            dr.polygon(quad, fill=col + (255,))
    img = img.resize((W, H), Image.LANCZOS)
    a = np.array(img).astype(np.float64)
    al = a[:, :, 3] / 255.0
    vis = al >= LATTICE_SCISSOR
    a[:, :, 3] = np.where(vis, 255.0, 0.0)
    out = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
    from . import leafatlas
    out = leafatlas.halo(out, alpha=LATTICE_HALO, px=2, scissor=LATTICE_SCISSOR)
    out = leafatlas.bleed(out, scissor=LATTICE_SCISSOR)
    return out, place


def build_lattice(model_id, spec3d):
    """The power pylon (see the section header)."""
    from cesprites import props_road as R
    from . import leafatlas
    t0 = time.time()
    R.PYLON_LOG = []
    try:
        rig, info, sspec = _build_source(spec3d)
        lg = R.PYLON_LOG[0]
    finally:
        R.PYLON_LOG = None
    size = tuple(spec3d.get("atlas", (1024, 1024)))
    ppm = float(spec3d.get("ppm", 40.0))
    panels = _lattice_panels(lg)
    img, place = _lattice_atlas(panels, size, ppm, spec3d.get("colour", "#8e959b"), spec3d.get("ins_colour", "#5f6f7d"))
    W, H = size
    mb = core.MeshBuilder()

    def uv_of(key, q):
        x0, y0, umin, vmax = place[key]
        return ((x0 + (q[0] - umin) * ppm) / W, (y0 + (vmax - q[1]) * ppm) / H)

    def add_poly(key, pts3, pts2, normal):
        for i in range(1, len(pts3) - 1):
            tri = [pts3[0], pts3[i], pts3[i + 1]]
            uvs = [uv_of(key, pts2[0]), uv_of(key, pts2[i]), uv_of(key, pts2[i + 1])]
            n = np.asarray(normal, dtype=np.float64)
            if np.cross(np.asarray(tri[1]) - tri[0], np.asarray(tri[2]) - tri[0]) @ n < 0:
                tri = [tri[0], tri[2], tri[1]]
                uvs = [uvs[0], uvs[2], uvs[1]]
            mb.add("baked_cutout", np.array([tri]), np.array([[n, n, n]]), uv=np.array([uvs]))
    for p in panels:
        key = p["key"]
        if "tower" in p:
            z0, z1, h0, h1 = p["section"]
            for pl in p["tower"]:
                n = pl["normal"]
                ex = pl["ex"]
                pts3 = []
                for (u, v) in p["poly"]:
                    # the plane of the face passes through the leg line: half width h(v) at height v
                    t = (v - z0) / max(1e-9, z1 - z0)
                    hv = h0 + (h1 - h0) * t
                    pts3.append(n * hv + ex * u + np.array([0.0, 0.0, v]))
                add_poly(key, pts3, p["poly"], n)
        elif "arm" in p:
            z, span, h_root, part = p["arm"]
            for side in (-1.0, 1.0):
                if part == "bottom":
                    pts3 = [np.array([side * (h_root + u), v, z]) for (u, v) in p["poly"]]
                    add_poly(key, pts3, p["poly"], (0.0, 0.0, -1.0))
                else:
                    du, rise, length = p["side_geo"]
                    ry, ty = lg["arm_root_y"], lg["arm_tip_y"]
                    for yy in (-1.0, 1.0):
                        # the sloped side through root-bottom (h_root, yy ry, z), tip (span, yy ty, z) and
                        # root-top (h_root + du, yy ry, z + rise): u along the arm, v up
                        def to3(u, v, _side=side, _yy=yy):
                            f = min(1.0, max(0.0, u / max(1e-9, length)))
                            y = _yy * (ry + (ty - ry) * f)
                            return np.array([_side * (h_root + u), y, z + v])
                        pts3 = [to3(u, v) for (u, v) in p["poly"]]
                        n = np.cross(pts3[1] - pts3[0], pts3[3] - pts3[0])
                        n = n / max(1e-9, np.linalg.norm(n))
                        if n[1] * yy < 0:
                            n = -n
                        add_poly(key, pts3, p["poly"], n)
        elif p.get("peak"):
            for (ex, nrm) in ((np.array([1.0, 0.0, 0.0]), np.array([0.0, -1.0, 0.0])),
                              (np.array([0.0, 1.0, 0.0]), np.array([1.0, 0.0, 0.0]))):
                pts3 = [ex * u + np.array([0.0, 0.0, v]) for (u, v) in p["poly"]]
                add_poly(key, pts3, p["poly"], nrm)
        elif p.get("insulator"):
            L = p["insulator"]
            for (xi, zi) in lg["insulators"]:
                top = zi - 0.4
                for k in range(6):
                    a0 = 2 * math.pi * k / 6
                    a1 = 2 * math.pi * (k + 1) / 6
                    r = 0.16
                    p0 = np.array([xi + math.cos(a0) * r, math.sin(a0) * r, 0.0])
                    p1 = np.array([xi + math.cos(a1) * r, math.sin(a1) * r, 0.0])
                    nm = np.array([math.cos((a0 + a1) / 2), math.sin((a0 + a1) / 2), 0.0])
                    pts3 = [p0 + [0, 0, top - L], p1 + [0, 0, top - L], p1 + [0, 0, top], p0 + [0, 0, top]]
                    add_poly(key, pts3, [(-0.17, 0.0), (0.17, 0.0), (0.17, L), (-0.17, L)], nm)
    pts = mb.points()
    model = _finish_model(model_id, spec3d, sspec, info, pts)
    model.lods = [Lod("lod0", 100000, [Part("body", "lod0_body", mb.finish(), auto_lod=False)])]
    model.roughness = float(spec3d.get("roughness", 0.55))
    model.texture_files["albedo.png"] = leafatlas.png_bytes(img)
    model.textures["albedo"] = "albedo.png"
    model.stats = dict(build_s=round(time.time() - t0, 2), panels=len(panels),
                       coverage=leafatlas.coverage(img, 6, scissor=LATTICE_SCISSOR))
    return model
