"""Material factory.

Every material contains the shared node group "CE_PASS" (one float output per sprite layer).
The render passes only change the values inside that group:
  base pass     -> base=1: the normal BSDF is used (lights off, daylight).
  layer passes  -> base=0, <layer>=1: the material outputs pure emission = its colour for that layer
                   (black for everything that does not glow -> occludes, becomes transparent later).
So procedural masks (e.g. lit windows) drive the base look and the night layer consistently.
"""
import math

import bpy

LAYERS = ("tail", "brake", "beacon_a", "beacon_b", "lights")
_PASS_GROUP = None


def srgb(c, alpha=1.0):
    """'#rrggbb' or (r,g,b) in sRGB 0..1 -> linear RGBA tuple."""
    if isinstance(c, str):
        h = c.lstrip("#")
        c = tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

    def lin(v):
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (lin(c[0]), lin(c[1]), lin(c[2]), alpha)


def scale_rgb(c, k):
    return (c[0] * k, c[1] * k, c[2] * k, 1.0)


def reset():
    global _PASS_GROUP
    _PASS_GROUP = None


def pass_group():
    global _PASS_GROUP
    if _PASS_GROUP is not None:
        return _PASS_GROUP
    g = bpy.data.node_groups.new("CE_PASS", "ShaderNodeTree")
    out = g.nodes.new("NodeGroupOutput")
    for i, name in enumerate(("base",) + LAYERS):
        g.interface.new_socket(name=name, in_out="OUTPUT", socket_type="NodeSocketFloat")
        v = g.nodes.new("ShaderNodeValue")
        v.name = "v_" + name
        v.outputs[0].default_value = 1.0 if name == "base" else 0.0
        v.location = (-300, -i * 80)
        g.links.new(v.outputs[0], out.inputs[i])
    _PASS_GROUP = g
    return g


def set_pass(layer):
    g = pass_group()
    for name in ("base",) + LAYERS:
        g.nodes["v_" + name].outputs[0].default_value = 1.0 if name == layer else 0.0


class NB:
    """Small node-building helper. Inputs may be numbers, tuples or sockets."""

    def __init__(self, tree):
        self.t = tree
        self.nodes = tree.nodes
        self.links = tree.links
        self._coords = None
        self._normal = None

    def node(self, kind, **props):
        n = self.nodes.new(kind)
        for k, v in props.items():
            setattr(n, k, v)
        return n

    def feed(self, sock, v):
        if v is None:
            return
        if hasattr(v, "is_output") or isinstance(v, bpy.types.NodeSocket):
            self.links.new(v, sock)
        else:
            sock.default_value = v

    def math(self, op, a, b=0.0, c=0.0, clamp=False):
        n = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
        self.feed(n.inputs[0], a)
        self.feed(n.inputs[1], b)
        self.feed(n.inputs[2], c)
        return n.outputs[0]

    def add(self, a, b):
        return self.math("ADD", a, b)

    def sub(self, a, b):
        return self.math("SUBTRACT", a, b)

    def mul(self, a, b):
        return self.math("MULTIPLY", a, b)

    def madd(self, a, b, c):
        return self.math("MULTIPLY_ADD", a, b, c)

    def gt(self, a, b):
        return self.math("GREATER_THAN", a, b)

    def lt(self, a, b):
        return self.math("LESS_THAN", a, b)

    def band(self, v, lo, hi):
        return self.mul(self.gt(v, lo), self.lt(v, hi))

    def AND(self, *xs):
        r = xs[0]
        for x in xs[1:]:
            r = self.mul(r, x)
        return r

    def OR(self, *xs):
        r = xs[0]
        for x in xs[1:]:
            r = self.math("MAXIMUM", r, x)
        return r

    def NOT(self, a):
        return self.math("SUBTRACT", 1.0, a)

    def absf(self, a):
        return self.math("ABSOLUTE", a)

    def mix(self, fac, a, b):
        n = self.node("ShaderNodeMix", data_type="RGBA", blend_type="MIX")
        self.feed(n.inputs["Factor"], fac)
        self.feed(_sock(n.inputs, "A_Color"), a)
        self.feed(_sock(n.inputs, "B_Color"), b)
        return _sock(n.outputs, "Result_Color")

    def mixf(self, fac, a, b):
        n = self.node("ShaderNodeMix", data_type="FLOAT")
        self.feed(n.inputs["Factor"], fac)
        self.feed(_sock(n.inputs, "A_Float"), a)
        self.feed(_sock(n.inputs, "B_Float"), b)
        return _sock(n.outputs, "Result_Float")

    def color_scale(self, col, k):
        n = self.node("ShaderNodeVectorMath", operation="SCALE")
        self.feed(n.inputs[0], col[:3] if isinstance(col, tuple) else col)
        self.feed(n.inputs["Scale"], k)
        return n.outputs[0]

    def vadd(self, a, b):
        n = self.node("ShaderNodeVectorMath", operation="ADD")
        self.feed(n.inputs[0], a[:3] if isinstance(a, tuple) else a)
        self.feed(n.inputs[1], b[:3] if isinstance(b, tuple) else b)
        return n.outputs[0]

    def coords(self, space="Object"):
        if self._coords is None:
            tc = self.node("ShaderNodeTexCoord")
            sep = self.node("ShaderNodeSeparateXYZ")
            self.links.new(tc.outputs[space], sep.inputs[0])
            sepn = self.node("ShaderNodeSeparateXYZ")
            self.links.new(tc.outputs["Normal"], sepn.inputs[0])
            self._coords = (sep.outputs[0], sep.outputs[1], sep.outputs[2], tc)
            self._normal = (sepn.outputs[0], sepn.outputs[1], sepn.outputs[2])
        return self._coords[:3]

    def normal(self):
        self.coords()
        return self._normal

    def texco(self, space="Object"):
        self.coords()
        return self._coords[3].outputs[space]

    def noise(self, scale, detail=2.0, rough=0.5, vec=None, dim="3D"):
        n = self.node("ShaderNodeTexNoise", noise_dimensions=dim)
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        self.feed(n.inputs["Vector"], vec if vec is not None else self.texco())
        return n.outputs["Fac"]

    def voronoi(self, scale, vec=None, feature="F1", out="Distance"):
        n = self.node("ShaderNodeTexVoronoi", feature=feature)
        n.inputs["Scale"].default_value = scale
        self.feed(n.inputs["Vector"], vec if vec is not None else self.texco())
        return n.outputs[out]

    def ramp(self, fac, stops):
        """stops: [(pos, rgba)]"""
        n = self.node("ShaderNodeValToRGB")
        cr = n.color_ramp
        while len(cr.elements) > len(stops):
            cr.elements.remove(cr.elements[-1])
        while len(cr.elements) < len(stops):
            cr.elements.new(0.5)
        for el, (p, c) in zip(cr.elements, stops):
            el.position = p
            el.color = c
        self.feed(n.inputs[0], fac)
        return n.outputs[0]

    def random(self):
        oi = self.node("ShaderNodeObjectInfo")
        return oi.outputs["Random"]

    def bump(self, height, strength=0.3, distance=0.05):
        n = self.node("ShaderNodeBump")
        n.inputs["Strength"].default_value = strength
        n.inputs["Distance"].default_value = distance
        self.feed(n.inputs["Height"], height)
        return n.outputs["Normal"]

    def halfplane(self, y, z, p, q, inset=0.0):
        """1 where point (y,z) is left of the directed edge p->q (counter-clockwise polygon inside)."""
        ex, ez = q[0] - p[0], q[1] - p[1]
        ln = math.hypot(ex, ez) or 1.0
        a, b = -ez / ln, ex / ln
        c = -(a * p[0] + b * p[1]) - inset
        return self.gt(self.madd(z, b, self.madd(y, a, c)), 0.0)

    def polygon(self, y, z, pts, inset=0.0):
        """Convex polygon mask (counter-clockwise points in the (y, z) plane)."""
        terms = [self.halfplane(y, z, pts[i], pts[(i + 1) % len(pts)], inset) for i in range(len(pts))]
        return self.AND(*terms)


def _sock(socks, ident):
    for s in socks:
        if s.identifier == ident:
            return s
    raise KeyError(ident)


def new_material(name):
    m = bpy.data.materials.new(name)
    try:
        if not m.node_tree:
            m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    return m, NB(nt)


def finish(m, nb, bsdf_out, emit=None):
    """Wires base BSDF and per-layer emission through the CE_PASS switch.
    emit: {layer: color (rgba tuple, already scaled by strength) or socket}."""
    grp = nb.node("ShaderNodeGroup")
    grp.node_tree = pass_group()
    em_col = (0.0, 0.0, 0.0)
    if emit:
        acc = None
        for layer, col in emit.items():
            term = nb.color_scale(col, grp.outputs[layer])
            acc = term if acc is None else nb.vadd(acc, term)
        em_col = acc
    em = nb.node("ShaderNodeEmission")
    nb.feed(em.inputs["Color"], em_col if not isinstance(em_col, tuple) else em_col + (1.0,))
    em.inputs["Strength"].default_value = 1.0
    mix = nb.node("ShaderNodeMixShader")
    nb.feed(mix.inputs[0], nb.NOT(grp.outputs["base"]))
    nb.links.new(bsdf_out, mix.inputs[1])
    nb.links.new(em.outputs[0], mix.inputs[2])
    out = nb.node("ShaderNodeOutputMaterial")
    nb.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


def principled(nb, color, rough=0.5, metal=0.0, coat=0.0, coat_rough=0.04, spec=0.5, normal=None,
               sheen=0.0, subsurface=0.0, transmission=0.0, ior=1.5):
    b = nb.node("ShaderNodeBsdfPrincipled")
    nb.feed(b.inputs["Base Color"], color)
    nb.feed(b.inputs["Roughness"], rough)
    nb.feed(b.inputs["Metallic"], metal)
    b.inputs["Coat Weight"].default_value = coat
    b.inputs["Coat Roughness"].default_value = coat_rough
    nb.feed(b.inputs["Specular IOR Level"], spec)
    b.inputs["Sheen Weight"].default_value = sheen
    b.inputs["Subsurface Weight"].default_value = subsurface
    b.inputs["Transmission Weight"].default_value = transmission
    b.inputs["IOR"].default_value = ior
    if normal is not None:
        nb.links.new(normal, b.inputs["Normal"])
    return b.outputs[0]


def emit_col(color, strength):
    c = srgb(color) if isinstance(color, str) else color
    return (c[0] * strength, c[1] * strength, c[2] * strength, 1.0)


def basic(name, color, rough=0.5, metal=0.0, coat=0.0, spec=0.5, emit=None, bump=None, sheen=0.0,
          color2=None, var_scale=None, subsurface=0.0):
    """Simple principled material. color/color2: sRGB hex or linear tuple.
    color2 + var_scale: noise colour variation (object space, var_scale = noise scale);
    color2 without var_scale: per-object random mix. bump: (scale, strength)."""
    m, nb = new_material(name)
    c1 = srgb(color) if isinstance(color, str) else color
    col = c1
    if color2 is not None:
        c2 = srgb(color2) if isinstance(color2, str) else color2
        fac = nb.noise(var_scale, detail=3.0) if var_scale else nb.random()
        if var_scale:
            fac = nb.math("MAP_RANGE", fac, 0.0, 1.0) if False else fac
            fac = nb.ramp(fac, [(0.35, (0, 0, 0, 1)), (0.65, (1, 1, 1, 1))])
        col = nb.mix(fac, c1, c2)
    normal = None
    if bump:
        normal = nb.bump(nb.noise(bump[0], detail=3.0), strength=bump[1], distance=0.02)
    out = principled(nb, col, rough=rough, metal=metal, coat=coat, spec=spec, normal=normal, sheen=sheen,
                     subsurface=subsurface)
    em = None
    if emit:
        em = {k: emit_col(v[0], v[1]) for k, v in emit.items()}
    return finish(m, nb, out, em)


def paint(name, color, metal=0.4, rough=0.3, coat=1.0, coat_rough=0.03, emit=None):
    """Car paint: base (solid or metallic) under a glossy clear coat."""
    m, nb = new_material(name)
    c = srgb(color) if isinstance(color, str) else color
    out = principled(nb, c, rough=rough, metal=metal, coat=coat, coat_rough=coat_rough, spec=0.5)
    em = {k: emit_col(v[0], v[1]) for k, v in emit.items()} if emit else None
    return finish(m, nb, out, em)


def glass_mat(name, tint="#0d1115", rough=0.012):
    """Car glass (opaque, dark tint): strong Fresnel reflections of the sky/horizon."""
    m, nb = new_material(name)
    out = principled(nb, srgb(tint), rough=rough, metal=0.0, coat=0.6, coat_rough=0.008, spec=0.8)
    return finish(m, nb, out, None)


def lens(name, tint="#9c1209", refl=0.07, rough=0.015, emit=None, frost=0.0):
    """Thin lamp lens (no refraction): tinted transparency + clear-coat-like reflection (Fresnel).
    In the light passes it is fully transparent (plus its own emission), so the lamp internals behind
    it glow through; the light passes therefore allow transparent bounces."""
    m, nb = new_material(name)
    tr = nb.node("ShaderNodeBsdfTransparent")
    tr.inputs["Color"].default_value = srgb(tint)
    gl = nb.node("ShaderNodeBsdfGlossy")
    gl.inputs["Roughness"].default_value = rough
    gl.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    fr = nb.node("ShaderNodeFresnel")
    fr.inputs["IOR"].default_value = 1.5
    fac = nb.math("MULTIPLY_ADD", fr.outputs[0], 1.0 - refl, refl, clamp=True)
    mix = nb.node("ShaderNodeMixShader")
    nb.feed(mix.inputs[0], fac)
    if frost > 0:
        df = nb.node("ShaderNodeBsdfDiffuse")
        df.inputs["Color"].default_value = srgb(tint)
        m2 = nb.node("ShaderNodeMixShader")
        m2.inputs[0].default_value = frost
        nb.links.new(tr.outputs[0], m2.inputs[1])
        nb.links.new(df.outputs[0], m2.inputs[2])
        nb.links.new(m2.outputs[0], mix.inputs[1])
    else:
        nb.links.new(tr.outputs[0], mix.inputs[1])
    nb.links.new(gl.outputs[0], mix.inputs[2])
    grp = nb.node("ShaderNodeGroup")
    grp.node_tree = pass_group()
    # light passes: transparent (white) + own emission
    tr2 = nb.node("ShaderNodeBsdfTransparent")
    tr2.inputs["Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    em = nb.node("ShaderNodeEmission")
    em_col = (0.0, 0.0, 0.0, 1.0)
    if emit:
        acc = None
        for layer, (ecol, strength) in emit.items():
            term = nb.color_scale(emit_col(ecol, strength), grp.outputs[layer])
            acc = term if acc is None else nb.vadd(acc, term)
        nb.feed(em.inputs["Color"], acc)
    else:
        em.inputs["Color"].default_value = em_col
    add = nb.node("ShaderNodeAddShader")
    nb.links.new(tr2.outputs[0], add.inputs[0])
    nb.links.new(em.outputs[0], add.inputs[1])
    sw = nb.node("ShaderNodeMixShader")
    nb.feed(sw.inputs[0], nb.NOT(grp.outputs["base"]))
    nb.links.new(mix.outputs[0], sw.inputs[1])
    nb.links.new(add.outputs[0], sw.inputs[2])
    out = nb.node("ShaderNodeOutputMaterial")
    nb.links.new(sw.outputs[0], out.inputs["Surface"])
    return m


def emissive_only(name, base_color, emit, rough=0.3):
    """Lamp lens: base look = base_color (lights off), emission per layer."""
    return basic(name, base_color, rough=rough, spec=0.6, coat=0.3, emit=emit)


def glass(name, tint="#1b232b", rough=0.03, emit=None):
    m, nb = new_material(name)
    out = principled(nb, srgb(tint), rough=rough, metal=0.0, spec=1.0, coat=0.0)
    em = {k: emit_col(v[0], v[1]) for k, v in emit.items()} if emit else None
    return finish(m, nb, out, em)


# --- surface shader: paint + livery bands + windows + decals --------------------------------------

PRESETS = {
    "lamp_red": dict(color="#8a0c0a", rough=0.1, coat=0.9, spec=1.0),
    "lamp_red_dark": dict(color="#3c0707", rough=0.12, coat=0.8, spec=0.9),
    "lamp_amber": dict(color="#c86a12", rough=0.12, coat=0.8, spec=0.9),
    "lamp_clear": dict(color="#b9bec4", rough=0.08, metal=0.5, coat=0.6, spec=0.9),
    "lamp_smoke": dict(color="#26292c", rough=0.08, metal=0.3, coat=0.8, spec=0.9),
    "black": dict(color="#141516", rough=0.55, spec=0.3),
    "gloss_black": dict(color="#0b0c0d", rough=0.12, coat=0.6, spec=0.6),
    "chrome": dict(color="#d9dbde", rough=0.1, metal=1.0, spec=0.8),
    "alu": dict(color="#a7abb0", rough=0.3, metal=1.0, spec=0.6),
    "plate": dict(color="#eeeeea", rough=0.45, spec=0.4),
    "plate_blue": dict(color="#1d3c9c", rough=0.45, spec=0.4),
    "plate_text": dict(color="#151515", rough=0.5, spec=0.3),
    "seal": dict(color="#0f1011", rough=0.5, spec=0.3),
    "glass": dict(color="#151c23", rough=0.03, spec=1.0),
    "reflector": dict(color="#8c1512", rough=0.2, coat=0.5, spec=0.8),
    "white": dict(color="#f2f2ef", rough=0.4, spec=0.4),
    "yellow": dict(color="#f2c81b", rough=0.4, spec=0.4),
    "orange": dict(color="#e8641a", rough=0.4, spec=0.4),
    "dark": dict(color="#26282b", rough=0.5, spec=0.4),
    "grey": dict(color="#7d8187", rough=0.5, spec=0.4),
}


def _preset(spec):
    if isinstance(spec, str):
        if spec in PRESETS:
            return PRESETS[spec]
        return dict(color=spec, rough=0.35, coat=0.5, spec=0.5)
    return spec


def decal_mask(nb, d):
    """Mask socket for a decal: face test on the object-space normal + polygon in face coordinates."""
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    face = d.get("face", "rear")
    thr = d.get("n", 0.35)
    if face == "rear":
        ftest = nb.lt(ny, -thr)
        u, v = (nb.absf(x) if d.get("sym", True) else x), z
    elif face == "front":
        ftest = nb.gt(ny, thr)
        u, v = (nb.absf(x) if d.get("sym", True) else x), z
    elif face == "side":
        ftest = nb.gt(nb.absf(nx), d.get("n", 0.5))
        u, v = y, z
        if d.get("only") == "right":
            ftest = nb.mul(ftest, nb.gt(nx, 0.0))
        elif d.get("only") == "left":
            ftest = nb.mul(ftest, nb.lt(nx, 0.0))
    elif face == "top":
        ftest = nb.gt(nz, d.get("n", 0.6))
        u, v = (nb.absf(x) if d.get("sym", True) else x), y
    else:  # any face, (x, z) plane
        ftest = 1.0
        u, v = (nb.absf(x) if d.get("sym", True) else x), z
    polys = d["poly"] if isinstance(d["poly"][0][0], (list, tuple)) else [d["poly"]]
    masks = [nb.polygon(u, v, p, inset=d.get("inset", 0.0)) for p in polys]
    m = nb.OR(*masks)
    if d.get("zmin") is not None:
        m = nb.mul(m, nb.gt(z, d["zmin"]))
    return nb.mul(m, ftest) if ftest != 1.0 else m


def surface(name, color, metal=0.35, rough=0.3, coat=0.7, livery=None, windows=None, plastic_below=None,
            decals=None, glass_tint="#151c23", roof_color=None, roof_z=None, spec=0.5, plastic_color="#1a1b1d"):
    """Body/surface shader in object space.
    livery: bands {z:(z0,z1), color, check:(cell_w, cell_h, color2), y:(y0,y1), side_only, rear_only}
    windows: greenhouse glass masks (see window_masks). plastic_below: z below which it is black plastic.
    decals: [{face, poly(s), sym, mat (preset/hex/dict), emit {layer: (color, strength)}, inset}] applied in order.
    roof_color/roof_z: other colour above roof_z."""
    m, nb = new_material(name)
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    base = srgb(color) if isinstance(color, str) else color
    col = base
    if roof_color is not None and roof_z is not None:
        col = nb.mix(nb.gt(z, roof_z), col, srgb(roof_color))
    for band in livery or []:
        z0, z1 = band["z"]
        mask = nb.band(z, z0, z1)
        if "y" in band:
            mask = nb.mul(mask, nb.band(y, band["y"][0], band["y"][1]))
        if band.get("side_only"):
            mask = nb.mul(mask, nb.gt(nb.absf(nx), 0.5))
        if band.get("rear_only"):
            mask = nb.mul(mask, nb.lt(ny, -0.35))
        if band.get("not_top"):
            mask = nb.mul(mask, nb.lt(nz, 0.75))
        bc = srgb(band["color"])
        if "check" in band:
            cw, chh, c2 = band["check"]
            side = nb.gt(nb.absf(nx), nb.absf(ny))
            u = nb.mixf(side, x, y)
            iu = nb.math("FLOOR", nb.math("DIVIDE", u, cw))
            iz = nb.math("FLOOR", nb.math("DIVIDE", nb.sub(z, z0), chh))
            par = nb.math("FLOORED_MODULO", nb.add(iu, iz), 2.0)
            bc = nb.mix(par, bc, srgb(c2))
        col = nb.mix(mask, col, bc)
    # One Principled BSDF; masks blend its inputs (a chain of BSDFs would exceed Cycles' closure budget).
    par = dict(col=col, rough=rough, metal=metal, coat=coat, spec=spec)

    def apply(mask, p):
        c = srgb(p["color"]) if isinstance(p["color"], str) else p["color"]
        par["col"] = nb.mix(mask, par["col"], c)
        par["rough"] = nb.mixf(mask, par["rough"], p.get("rough", 0.4))
        par["metal"] = nb.mixf(mask, par["metal"], p.get("metal", 0.0))
        par["coat"] = nb.mixf(mask, par["coat"], p.get("coat", 0.0))
        par["spec"] = nb.mixf(mask, par["spec"], p.get("spec", 0.5))

    if plastic_below is not None:
        apply(nb.lt(z, plastic_below), dict(color=plastic_color, rough=0.6, spec=0.3))
    if windows:
        frame_m, glass_m = window_masks(nb, windows)
        apply(frame_m, dict(color="#101112", rough=0.5, spec=0.3))
        apply(glass_m, dict(color=glass_tint, rough=0.03, spec=1.0, coat=0.0))
    # decals grouped per material in first-appearance order (one OR-ed mask per material)
    emit = {}
    groups = []
    index = {}
    for d in decals or []:
        mask = decal_mask(nb, d)
        p = _preset(d.get("mat", "black"))
        key = repr(sorted(p.items()))
        if key not in index:
            index[key] = len(groups)
            groups.append([p, []])
        groups[index[key]][1].append(mask)
        for layer, (ecol, strength) in (d.get("emit") or {}).items():
            term = nb.color_scale(emit_col(ecol, strength), mask)
            emit[layer] = term if layer not in emit else nb.vadd(emit[layer], term)
    for p, masks in groups:
        apply(nb.OR(*masks), p)
    shader = principled(nb, par["col"], rough=par["rough"], metal=par["metal"], coat=0.0, coat_rough=0.03,
                        spec=par["spec"])
    b = shader.node
    nb.feed(b.inputs["Coat Weight"], par["coat"])
    return finish(m, nb, shader, emit or None)


def car_paint(name, color, **kw):
    return surface(name, color, **kw)


def window_masks(nb, w):
    """Returns (frame_mask, glass_mask) sockets for a greenhouse window spec:
      side: [convex polygons in (y,z)] on side faces (|n.x| > side_nx)
      front/rear: dict(y=(y0,y1), z=(z0,z1), wb, zb, tumble, pillar) on non-side faces
      frame: seal width (m)."""
    x, y, z = nb.coords()
    nx, ny, nz = nb.normal()
    fr = w.get("frame", 0.018)
    is_side = nb.gt(nb.absf(nx), w.get("side_nx", 0.45))
    not_side = nb.NOT(is_side)
    frames, glasses = [], []
    for poly in w.get("side", []):
        glasses.append(nb.polygon(y, z, poly, inset=fr))
    for poly in w.get("side_frames", w.get("side", [])):
        frames.append(nb.polygon(y, z, poly))
    side_f = nb.mul(is_side, nb.OR(*frames)) if frames else 0.0
    side_g = nb.mul(is_side, nb.OR(*glasses)) if glasses else 0.0
    tf, tg = [], []
    ax = nb.absf(x)
    for key in ("front", "rear"):
        s = w.get(key)
        if not s:
            continue
        # |x| < wb - tumble*(z - zb) - pillar  <=>  wb - pillar - tumble*(z-zb) - |x| > 0
        lim = nb.sub(nb.madd(nb.sub(z, s["zb"]), -s["tumble"], s["wb"] - s["pillar"]), ax)
        reg = nb.AND(nb.band(y, s["y"][0], s["y"][1]), nb.band(z, s["z"][0], s["z"][1]))
        dir_ok = nb.gt(ny, s.get("ny_min", -2.0)) if key == "front" else nb.lt(ny, s.get("ny_max", 2.0))
        tf.append(nb.AND(not_side, reg, nb.gt(lim, 0.0), dir_ok))
        reg_g = nb.AND(nb.band(y, s["y"][0] + fr, s["y"][1] - fr), nb.band(z, s["z"][0] + fr, s["z"][1] - fr))
        tg.append(nb.AND(not_side, reg_g, nb.gt(lim, fr), dir_ok))
    frame = nb.OR(side_f, *tf) if tf else side_f
    glass_m = nb.OR(side_g, *tg) if tg else side_g
    return frame, glass_m
