"""Material roles: what a generator material becomes in the real-time model (docs/modelle.md).

The generators tag their materials and objects with custom properties (hooks in cesprites, no effect on
the sprite renders):
  material["ce_role"]  flat | paint | glass | lens | surface | proc | fx
  material["ce_data"]  JSON: color / color2 (linear rgb), rough, metal, coat, emit {layer: [r, g, b]},
                       tint, frost, slot (paint slot of a 'paint' role: paint | paint2 | paint3)
  object["ce_node"]    node of the model the object belongs to (body, wheel_0l, ...; "none" = sprite only)
  object["ce_lamp"]    lamp channel of every face of the object ("ind", "head", "drl:0.8", ...), overrides
                       what the emission of the material says; a leading "-" ("-marker:1:#ffa21a") = a lamp
                       without a light anchor in the manifest (side markers, the plate lamp)
  material["ce_node"]  faces with this material go to that node instead (brake calipers -> body)
An untagged object or material is an error: nothing is guessed from names.

Vertex format "VPBR-L" of the class vpbr (contract 4.6.4):
  COLOR.rgb  albedo as sRGB bytes; for the lamp channels the LIT colour - except the lit SURFACES plate (8)
             and flood (14), which keep their own albedo and roughness and get their light added
  COLOR.a    paint code: 255 fixed colour, 0 paint, 64 paint2, 128 paint3
  UV         (roughness, metallic)
  UV2        (lamp channel + 0.5, weight 0..1) or (-1, 0)
Class glass: COLOR.rgb tint, COLOR.a opacity, UV = (roughness, metallic).
"""
import json

import numpy as np

from . import core

CHANNELS = {"tail": 0, "brake": 1, "tail_brake": 2, "ind_l": 3, "ind_r": 4, "head": 5, "drl": 6, "reverse": 7,
            "plate": 8, "marker": 9, "beacon_a": 10, "beacon_b": 11, "lights": 12, "on": 13, "flood": 14}
CHANNEL_NAMES = {v: k for k, v in CHANNELS.items()}
# lit surfaces, not lamps: the vertex colour is their own albedo (a number plate drawn as an unlit lamp was grey)
SURFACE_CHANNELS = ("plate", "flood")
PAINT_CODES = {"fixed": 255, "paint": 0, "paint2": 64, "paint3": 128}
NO_LAMP = (-1.0, 0.0)
# lit colours of lamps whose sprite material has no emission (indicators, headlights ... are not part of
# the sprite light layers)
LIT = {"ind_l": "#ffa01a", "ind_r": "#ffa01a", "head": "#fff3d6", "drl": "#eef3ff", "reverse": "#fff6e6",
       "plate": "#fff4dc", "marker": "#ffa21a", "tail": "#ff1a0e", "brake": "#ff2414", "tail_brake": "#ff2010",
       "beacon_a": "#2a6bff", "beacon_b": "#2a6bff", "lights": "#fff0cf", "on": "#ffffff"}
# anchors (manifest "lights") are written for these roles; tail_brake surfaces give a tail and a brake anchor
ANCHOR_ROLES = {"tail": ("tail",), "brake": ("brake",), "tail_brake": ("tail", "brake"), "ind_l": ("ind_l",),
                "ind_r": ("ind_r",), "head": ("head",), "beacon_a": ("beacon_a",), "beacon_b": ("beacon_b",),
                "lights": ("lights",), "marker": ("marker",)}


class RoleError(Exception):
    pass


def tag(mat):
    """(role, data) of a tagged material."""
    if mat is None:
        raise RoleError("face without a material")
    role = mat.get("ce_role")
    if role is None:
        raise RoleError("material '%s' has no ce_role tag (cesprites.materials sets it)" % mat.name)
    raw = mat.get("ce_data")
    return str(role), (json.loads(raw) if raw else {})


def node_of(ob):
    n = ob.get("ce_node")
    if n is None:
        raise RoleError("object '%s' has no ce_node tag" % ob.name)
    return str(n)


def lamp_from_emit(emit):
    """Lamp channel of a sprite emission dict {layer: [r, g, b] linear, strength folded in}:
    (channel name, weight, lit colour linear rgb) or None."""
    if not emit:
        return None
    e = {k: np.asarray(v, dtype=np.float64) for k, v in emit.items() if max(v) > 1e-4}
    if not e:
        return None
    st = {k: float(v.max()) for k, v in e.items()}

    def lit(k):
        return e[k] / st[k]
    for layer in ("beacon_a", "beacon_b", "lights"):
        if layer in e:
            return layer, min(1.0, st[layer]), lit(layer)
    t, b = st.get("tail", 0.0), st.get("brake", 0.0)
    if t > 0.0 and b > t * 1.05:
        return "tail_brake", min(1.0, b), lit("brake")
    if t > 0.0:
        return "tail", min(1.0, t), lit("tail")
    if b > 0.0:
        return "brake", min(1.0, b), lit("brake")
    return None


def parse_lamp(spec):
    """'ind', 'head:0.8', 'drl:1:#ffffff' -> (name, weight, lit colour or None)."""
    parts = str(spec).split(":")
    name = parts[0]
    w = float(parts[1]) if len(parts) > 1 and parts[1] else 1.0
    col = core.hex_to_lin(parts[2]) if len(parts) > 2 and parts[2] else None
    if name not in CHANNELS and name != "ind":
        raise RoleError("unknown lamp channel '%s'" % name)
    return name, w, col


class Translator:
    """Turns the triangles of tagged objects into class surfaces.

    overrides: {material name: dict(role=..., color=hex, rough=, metal=, lamp=..., slot=..., skip=True,
               opacity=...)} set by the model builder (flat colour of a procedural material, paint slots ...)
    glass_opacity: opacity of glazing (1.0 = opaque, traffic cars without an interior)
    lens_opacity / clear_lens_opacity: coloured lamp lenses / clear headlight lenses (class glass)
    glass_class: False = no glass surface (far levels): glazing becomes dark glossy vpbr, lenses are dropped
    """

    def __init__(self, overrides=None, glass_opacity=1.0, lens_opacity=0.42, glass_class=True, default_paint=None,
                 bake_names=None, clear_lens_opacity=0.14):
        self.overrides = overrides or {}
        self.glass_opacity = glass_opacity
        self.lens_opacity = lens_opacity
        self.clear_lens_opacity = clear_lens_opacity
        self.glass_class = glass_class
        self.default_paint = default_paint or {}
        self.bake_names = set(bake_names or [])
        self.anchors = []          # (role, corners (N, 3, 3) | centres (N, 3) Blender space, areas (N), lit colour)
        self.stats = {}

    def describe(self, mat):
        role, d = tag(mat)
        ov = self.overrides.get(mat.name) or self.overrides.get(role + ":*")
        if ov:
            d = dict(d)
            d.update(ov)
            role = d.get("role", role)
        return role, d

    def add_object(self, mb, soup, lamp_tag=None):
        """Adds the triangles of one soup to the MeshBuilder; returns the roles that could not be
        translated ({'surface', 'proc'} need decal geometry or a bake)."""
        left = set()
        for mi in np.unique(soup.mi):
            mat = soup.material(int(mi))
            sel = soup.mi == mi
            role, d = self.describe(mat)
            if d.get("skip") or role == "fx":
                continue
            if role in ("surface", "proc"):
                left.add(role)
                continue
            pos, nor = soup.pos[sel], soup.nor[sel]
            self.add_role(mb, role, d, pos, nor, lamp_tag or soup.ob.get("ce_lamp"))
        return left

    def add_role(self, mb, role, d, pos, nor, lamp_tag=None):
        rough = float(d.get("rough", 0.5))
        metal = float(d.get("metal", 0.0))
        if role == "glass" and lamp_tag is None:
            col = np.empty(4, dtype=np.uint8)
            col[:3] = core.srgb8(_color(d, (0.006, 0.008, 0.01)))
            col[3] = int(round(255 * float(d.get("opacity", self.glass_opacity))))
            if self.glass_class:
                mb.add("glass", pos, nor, col, (rough, metal))
            else:
                col[3] = 255
                mb.add("vpbr", pos, nor, col, (max(rough, 0.06), metal), NO_LAMP)
            return
        if role == "lens" and lamp_tag is None:
            if not self.glass_class:
                return                       # coarse LODs: the lamp internals carry the look
            tint = _color(d, (0.8, 0.8, 0.8), key="tint")
            # clear lenses (headlights) are nearly invisible, coloured ones veil what is behind them
            base = self.clear_lens_opacity if float(np.min(tint)) > 0.45 else self.lens_opacity
            col = np.empty(4, dtype=np.uint8)
            col[:3] = core.srgb8(tint)
            col[3] = int(round(255 * float(d.get("opacity", base + 0.25 * float(d.get("frost", 0.0))))))
            mb.add("glass", pos, nor, col, (0.05, 0.0))
            return
        lamp = None
        anchor = True
        if isinstance(lamp_tag, str) and lamp_tag.startswith("-"):
            lamp_tag, anchor = lamp_tag[1:], False
        if lamp_tag == "none":
            d = dict(d)
            d.pop("emit", None)             # explicitly not a lamp (front number plate)
        elif lamp_tag is not None:
            name, w, lit = parse_lamp(lamp_tag)
            if lit is None:
                lit = core.hex_to_lin(d["lit"]) if d.get("lit") else None
            lamp = (name, w, lit)
        elif d.get("lamp"):
            spec = str(d["lamp"])
            if spec.startswith("-"):
                spec, anchor = spec[1:], False
            lamp = parse_lamp(spec)
        else:
            lamp = lamp_from_emit(d.get("emit"))
        base = _color(d, (0.5, 0.5, 0.5))
        code = PAINT_CODES["fixed"]
        if role == "paint":
            slot = d.get("slot", "paint")
            code = PAINT_CODES[slot]
            if slot in self.default_paint:
                base = core.hex_to_lin(self.default_paint[slot])
        if lamp is None:
            col = np.empty(4, dtype=np.uint8)
            col[:3] = core.srgb8(base)
            col[3] = code
            mb.add("vpbr", pos, nor, col, (rough, metal), NO_LAMP)
            return
        name, w, lit = lamp
        if name == "ind":
            # one symmetric object carries both sides: split by the side of each triangle
            cx = pos[:, :, 0].mean(axis=1)
            for side, sel in (("ind_r", cx >= 0.0), ("ind_l", cx < 0.0)):
                if sel.any():
                    self._lamp(mb, side, w, lit, base, rough, metal, pos[sel], nor[sel], anchor)
            return
        self._lamp(mb, name, w, lit, base, rough, metal, pos, nor, anchor)

    def _lamp(self, mb, name, w, lit, base, rough, metal, pos, nor, anchor=True):
        ch = CHANNELS[name]
        if lit is None:
            lit = core.hex_to_lin(LIT.get(name, "#ffffff"))
        col = np.empty(4, dtype=np.uint8)
        col[:3] = core.srgb8(base if name in SURFACE_CHANNELS else lit)
        col[3] = PAINT_CODES["fixed"]
        w = float(min(1.0, max(0.0, w)))
        mb.add("vpbr", pos, nor, col, (rough, metal), (ch + 0.5, w))
        if anchor and name in ANCHOR_ROLES and w >= 0.25:
            self.anchors.append((name, np.asarray(pos, dtype=np.float64), core.tri_areas(pos),
                                 np.asarray(lit, dtype=np.float64)))

    # --- lamp anchors ---------------------------------------------------------------------------------

    def lights(self, min_area=2e-4, merge_m=0.35, origin=None, split_x=0.3):
        """Manifest "lights": one anchor per lamp cluster [{role, pos (model space), dir, size, color}].
        Triangles of one role are clustered by distance (merge_m); size = diameter of the circle with the
        cluster's area. A cluster that reaches over both sides of the vehicle (|x| > split_x) is split into
        a left and a right anchor; split_x = 0 keeps it whole.
        pos lies ON the lamp: the area-weighted centre of a curved cluster lies under its surface (28 mm for
        the tail lamp that wraps around a corner) - a depth-tested flare put there would sit inside the body.
        So the centre is moved along the cluster's mean normal onto the plane of the lamp triangle that this
        line passes closest to. dir = that mean outward normal (unit vector, model space): where the lamp
        looks - a flare is pushed that way (or towards the camera), a lamp facing away needs none.
        Anchors given as bare centres (lamps of baked models: tr.anchors.append((role, centres, areas, lit)))
        keep the centre and get no dir."""
        out = []
        by_role = {}
        for (name, geo, area, lit) in self.anchors:
            geo = np.asarray(geo, dtype=np.float64)
            tri = geo if geo.ndim == 3 else None
            cen = geo.mean(axis=1) if tri is not None else geo
            if tri is not None:
                nrm = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
                nrm = nrm / np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-12)
            else:
                nrm = np.zeros_like(cen)
            for role in ANCHOR_ROLES[name]:
                e = by_role.setdefault(role, [[], [], lit, []])
                e[0].append(cen)
                e[1].append(area)
                e[3].append(nrm)
        for role in sorted(by_role):
            cen = np.concatenate(by_role[role][0])
            area = np.concatenate(by_role[role][1])
            nrm = np.concatenate(by_role[role][3])
            lit = by_role[role][2]
            groups = []
            for idx in _clusters(cen, merge_m):
                x = cen[idx][:, 0]
                if split_x > 0.0 and x.min() < -split_x and x.max() > split_x:
                    # a lamp across the whole car (light bar): one anchor per side, and the middle if it is big
                    groups += [idx[x < -split_x], idx[x > split_x]]
                    mid = idx[np.abs(x) <= split_x]
                    if mid.size and float(area[mid].sum()) >= 0.5 * float(area[idx].sum()):
                        groups.append(mid)
                else:
                    groups.append(idx)
            for idx in groups:
                a = float(area[idx].sum())
                if a < min_area:
                    continue
                p = (cen[idx] * area[idx][:, None]).sum(axis=0) / a
                direction = None
                n = (nrm[idx] * area[idx][:, None]).sum(axis=0)
                ln = float(np.linalg.norm(n))
                if ln < 0.25 * a and abs(float(p[0])) > 1e-6:
                    # a closed lamp body (the indicator strip of a mirror): its normals cancel out - take the
                    # half that looks away from the middle of the vehicle
                    out_side = nrm[idx][:, 0] * np.sign(p[0]) > 0.0
                    if out_side.any():
                        n = (nrm[idx][out_side] * area[idx][out_side][:, None]).sum(axis=0)
                        ln = float(np.linalg.norm(n))
                if ln > 1e-9:
                    n = n / ln
                    # the lamp triangle whose centre lies closest to the line p + t n, among those that face along n
                    rel = cen[idx] - p
                    along = rel @ n
                    off = np.linalg.norm(rel - along[:, None] * n, axis=1)
                    facing = (nrm[idx] @ n) > 0.3
                    if facing.any():
                        off = np.where(facing, off, np.inf)
                    j = int(np.argmin(off))
                    denom = float(nrm[idx][j] @ n)
                    if abs(denom) > 0.3:
                        p = p + n * (float(rel[j] @ nrm[idx][j]) / denom)
                    direction = [round(v, 3) + 0.0 for v in core.model_point(n)]
                if origin is not None:
                    p = p - np.asarray(origin)
                entry = {"role": role, "pos": core.model_point(p)}
                if direction is not None:
                    entry["dir"] = direction
                entry["size"] = round(2.0 * (a / np.pi) ** 0.5, 3)
                entry["color"] = core.lin_to_hex(lit)
                out.append(entry)
        out.sort(key=lambda e: (e["role"], e["pos"][0], e["pos"][1], e["pos"][2]))
        return out


def _color(d, default, key="color"):
    c = d.get(key)
    if c is None:
        return np.asarray(default, dtype=np.float64)
    if isinstance(c, str):
        return core.hex_to_lin(c)
    c = np.asarray(c[:3], dtype=np.float64)
    c2 = d.get("color2")
    if key == "color" and c2 is not None:
        c = (c + np.asarray(c2[:3], dtype=np.float64)) * 0.5     # noise / per-object variation: the mean
    return c


def _clusters(pts, dist):
    """Single-linkage clusters of points on a grid of cell size dist (deterministic)."""
    n = pts.shape[0]
    if n == 0:
        return []
    cell = np.floor(pts / dist).astype(np.int64)
    keys, inv = np.unique(cell, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    m = keys.shape[0]
    parent = list(range(m))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    index = {tuple(k): i for i, k in enumerate(keys.tolist())}
    for i, k in enumerate(keys.tolist()):
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    j = index.get((k[0] + dx, k[1] + dy, k[2] + dz))
                    if j is not None and j != i:
                        ra, rb = find(i), find(j)
                        if ra != rb:
                            parent[max(ra, rb)] = min(ra, rb)
    roots = np.array([find(i) for i in range(m)])[inv]
    return [np.nonzero(roots == r)[0] for r in sorted(set(roots.tolist()))]
