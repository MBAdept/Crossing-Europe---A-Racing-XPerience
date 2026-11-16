from patchlib import patch

patch("tools/blender/ce3d/roles.py", [
    ('''        if role == "lens" and lamp_tag is None:
            if not self.glass_class:
                return                       # coarse LODs: the lamp internals carry the look
            col = np.empty(4, dtype=np.uint8)
            col[:3] = core.srgb8(_color(d, (0.8, 0.8, 0.8), key="tint"))
            col[3] = int(round(255 * float(d.get("opacity", self.lens_opacity + 0.25 * float(d.get("frost", 0.0))))))
            mb.add("glass", pos, nor, col, (0.05, 0.0))
            return
        lamp = None
        if lamp_tag is not None:
            name, w, lit = parse_lamp(lamp_tag)
            if lit is None:
                lit = core.hex_to_lin(d["lit"]) if d.get("lit") else None
            lamp = (name, w, lit)
        elif d.get("lamp"):''', '''        if role == "lens" and lamp_tag is None:
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
        if lamp_tag == "none":
            d = dict(d)
            d.pop("emit", None)             # explicitly not a lamp (front number plate)
        elif lamp_tag is not None:
            name, w, lit = parse_lamp(lamp_tag)
            if lit is None:
                lit = core.hex_to_lin(d["lit"]) if d.get("lit") else None
            lamp = (name, w, lit)
        elif d.get("lamp"):'''),
    ('''    def __init__(self, overrides=None, glass_opacity=1.0, lens_opacity=0.42, glass_class=True, default_paint=None,
                 bake_names=None):
        self.overrides = overrides or {}
        self.glass_opacity = glass_opacity
        self.lens_opacity = lens_opacity''', '''    def __init__(self, overrides=None, glass_opacity=1.0, lens_opacity=0.42, glass_class=True, default_paint=None,
                 bake_names=None, clear_lens_opacity=0.14):
        self.overrides = overrides or {}
        self.glass_opacity = glass_opacity
        self.lens_opacity = lens_opacity
        self.clear_lens_opacity = clear_lens_opacity'''),
    ('''    lens_as: 'glass' (clear lenses over lamp internals) | 'lamp' (lens drawn as the lamp itself, coarse LODs)
    """''', '''    lens_opacity / clear_lens_opacity: coloured lamp lenses / clear headlight lenses (class glass)
    glass_class: False = no glass surface (far levels): glazing becomes dark glossy vpbr, lenses are dropped
    """'''),
])
