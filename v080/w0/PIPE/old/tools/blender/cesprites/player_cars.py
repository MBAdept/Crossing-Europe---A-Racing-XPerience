"""The five player cars - smooth, detailed models (carbody.SmoothCar + cardetail).

Dimensions exactly from config/game_config.json (vehicles.types.*.length_m / width_m). Vehicle space:
y = 0 at the rear bumper, +y forward, x = 0 centre (+x right), z = 0 ground (rear projection outlines
are (x, z) of the RIGHT side and mirrored; side outlines are (y, z) on the right flank and mirrored).

  kompakt       hot hatch, yellow, gloss-black roof + roof spoiler, wedge lamps with LED hook,
                centre twin exhaust, black diffuser
  kombi         estate, green metallic, roof rails, L-shaped D-pillar lamps, chrome strip, trapezoid tips
  limousine     sedan, blue metallic, full-width LED light bar, lip spoiler, integrated tips
  sportwagen    fastback coupe, red, carbon wing, twin round lamps per side, quad exhaust, big diffuser
  gran_turismo  long-hood GT, silver, ducktail, slim full-width light strip, quad oval exhausts
"""
from . import carbody as CB
from . import cardetail as CD
from . import curves as C
from . import materials as M

# ---------------------------------------------------------------------------------------------- designs

KOMPAKT = dict(
    L=4.10, W=1.78, wb=2.62, r_oh=0.66, R=0.322, arch_gap=0.036, tw=0.225, arch_flare=(0.016, 0.09),
    bump_rear=dict(out=0.03, z_top=0.53, z_bot=[(0.0, 0.225), (0.3, 0.2), (0.6, 0.17)], r_plan=0.3, p_plan=2.5,
                   r_end_bot=0.04),
    bump_front=dict(out=0.035, z_top=0.50, z_bot=[(3.5, 0.17), (4.1, 0.2)], r_plan=0.5, r_end_bot=0.06),
    plan=[(0.0, 0.874), (0.66, 0.89), (1.35, 0.878), (2.3, 0.876), (3.28, 0.886), (4.1, 0.872)],
    r_plan=(0.26, 0.46), p_plan=(2.5, 2.0),
    deck=[(0.04, 0.975), (0.5, 0.99), (1.5, 0.982), (2.6, 0.962), (3.0, 0.94), (3.5, 0.875), (3.9, 0.80), (4.07, 0.74)],
    crown=[(0.0, 0.028), (2.9, 0.028), (3.2, 0.045), (4.1, 0.04)],
    r_top=(0.07, 0.15), r_bot=(0.05, 0.08),
    under=[(0.0, 0.23), (0.3, 0.17), (0.7, 0.14), (3.4, 0.14), (3.8, 0.17), (4.1, 0.22)],
    shoulder=[(0.0, 0.80), (2.0, 0.812), (4.1, 0.785)],
    tuck=0.055, tumble_up=0.032, r_edge=0.07, r_bottom=0.045,
    g_range=(0.07, 3.0),
    roof=[(0.07, 0.93), (0.115, 1.06), (0.18, 1.18), (0.29, 1.31), (0.43, 1.39), (0.66, 1.425), (1.2, 1.435),
          (1.9, 1.43), (2.22, 1.395), (2.52, 1.27), (2.82, 1.08), (3.0, 0.93)],
    g_inset=0.035, tumble=0.34, r_roof=0.075, roof_crown=0.04,
    roof_taper=[(0.0, 0.06), (0.3, 0.035), (0.7, 0.0), (2.0, 0.0), (2.9, 0.02)],
    wheel_inset=0.022,
    rims=dict(color="#1d1e21", metal=0.6, rough=0.25, coat=0.8, spokes=6, kind="twin", spoke_w=(0.05, 0.034),
              dish=0.035, caliper="#c8161b"),
    glass=dict(dlo=dict(y_rear=0.98, y_rear_top=1.24, y_front=2.95, top=0.026, bottom=0.012,
                        pillars=[(1.99, 1.95, 0.07)]),
               ws=dict(bottom=2.86, top=2.26, pillar=0.055),
               rw=dict(bottom=0.11, top=0.36, pillar=0.075, proj="rear")),
)

KOMBI = dict(
    L=4.80, W=1.85, wb=2.83, r_oh=0.98, R=0.333, arch_gap=0.036, tw=0.235, arch_flare=(0.008, 0.08), extra_h=0.065,
    bump_rear=dict(out=0.03, z_top=0.53, z_bot=[(0.0, 0.24), (0.35, 0.2), (0.8, 0.17)], r_plan=0.26, p_plan=2.6,
                   r_end_bot=0.04),
    bump_front=dict(out=0.035, z_top=0.52, z_bot=[(4.2, 0.17), (4.8, 0.2)], r_plan=0.5, r_end_bot=0.06),
    plan=[(0.0, 0.905), (0.98, 0.922), (1.8, 0.918), (3.0, 0.915), (3.81, 0.924), (4.8, 0.905)],
    r_plan=(0.22, 0.48), p_plan=(2.6, 2.0),
    deck=[(0.03, 0.975), (0.6, 0.99), (2.0, 0.985), (3.2, 0.965), (3.6, 0.945), (4.1, 0.865), (4.55, 0.785),
          (4.77, 0.725)],
    crown=[(0.0, 0.025), (3.6, 0.03), (3.9, 0.045), (4.8, 0.04)],
    r_top=(0.06, 0.16), r_bot=(0.05, 0.08),
    under=[(0.0, 0.24), (0.35, 0.17), (0.9, 0.145), (4.0, 0.145), (4.4, 0.17), (4.8, 0.22)],
    shoulder=[(0.0, 0.82), (2.4, 0.83), (4.8, 0.80)],
    tuck=0.05, tumble_up=0.03, r_edge=0.065, r_bottom=0.045,
    g_range=(0.06, 3.70),
    roof=[(0.06, 0.93), (0.085, 1.10), (0.11, 1.26), (0.15, 1.375), (0.24, 1.44), (0.45, 1.462), (1.5, 1.472),
          (2.6, 1.468), (2.95, 1.43), (3.25, 1.29), (3.55, 1.08), (3.70, 0.93)],
    g_inset=0.035, tumble=0.30, r_roof=0.07, roof_crown=0.035,
    roof_taper=[(0.0, 0.035), (0.3, 0.012), (0.6, 0.0), (2.6, 0.0), (3.5, 0.02)],
    wheel_inset=0.02,
    rims=dict(color="#c9cdd2", metal=1.0, rough=0.2, coat=0.4, spokes=10, kind="straight", spoke_w=(0.03, 0.022),
              dish=0.02, caliper="#3a3c3f", phase=90.0),
    glass=dict(dlo=dict(y_rear=0.47, y_rear_top=0.30, y_front=3.62, top=0.024, bottom=0.012,
                        pillars=[(2.36, 2.32, 0.07), (1.28, 1.33, 0.085)]),
               ws=dict(bottom=3.58, top=2.98, pillar=0.055),
               rw=dict(bottom=0.09, top=0.215, pillar=0.085, proj="rear")),
)

LIMOUSINE = dict(
    L=4.85, W=1.86, wb=2.92, r_oh=0.95, R=0.335, arch_gap=0.036, tw=0.235, arch_flare=(0.008, 0.08),
    bump_rear=dict(out=0.025, z_top=0.585, z_bot=[(0.0, 0.245), (0.35, 0.2), (0.8, 0.17)], r_plan=0.3, p_plan=2.4,
                   r_end_bot=0.04),
    bump_front=dict(out=0.035, z_top=0.52, z_bot=[(4.2, 0.17), (4.85, 0.2)], r_plan=0.52, r_end_bot=0.06),
    plan=[(0.0, 0.91), (0.95, 0.93), (1.8, 0.925), (3.0, 0.922), (3.87, 0.93), (4.85, 0.91)],
    r_plan=(0.28, 0.5), p_plan=(2.4, 2.0),
    deck=[(0.03, 1.035), (0.12, 1.04), (0.35, 1.03), (0.8, 1.035), (1.2, 1.04), (2.5, 1.02), (3.4, 0.99), (3.8, 0.965),
          (4.3, 0.88), (4.65, 0.80), (4.82, 0.74)],
    crown=[(0.0, 0.028), (3.7, 0.03), (4.0, 0.045), (4.85, 0.04)],
    r_top=(0.04, 0.16), r_bot=(0.05, 0.08),
    under=[(0.0, 0.25), (0.35, 0.17), (0.95, 0.145), (4.1, 0.145), (4.5, 0.17), (4.85, 0.22)],
    shoulder=[(0.0, 0.86), (2.4, 0.86), (4.85, 0.82)],
    tuck=0.05, tumble_up=0.03, r_edge=0.06, r_bottom=0.045,
    g_range=(0.95, 3.80),
    roof=[(0.95, 0.99), (1.03, 1.10), (1.18, 1.215), (1.42, 1.325), (1.72, 1.405), (2.05, 1.44), (2.6, 1.448),
          (3.0, 1.425), (3.22, 1.365), (3.45, 1.24), (3.68, 1.08), (3.80, 0.97)],
    g_inset=0.04, tumble=0.32, r_roof=0.07, roof_crown=0.035,
    roof_taper=[(0.9, 0.04), (1.4, 0.012), (2.0, 0.0), (3.0, 0.0), (3.7, 0.02)],
    wheel_inset=0.02,
    rims=dict(color="#b6bac0", metal=1.0, rough=0.22, coat=0.5, spokes=5, kind="twin", spoke_w=(0.06, 0.044),
              twin_gap=9.0, dish=0.03, caliper="#2f3134"),
    glass=dict(dlo=dict(y_rear=1.52, y_rear_top=1.82, y_front=3.70, top=0.024, bottom=0.012,
                        pillars=[(2.47, 2.43, 0.07)]),
               ws=dict(bottom=3.68, top=3.03, pillar=0.055),
               rw=dict(bottom=1.06, top=1.86, pillar=0.075, proj="top")),
)

SPORTWAGEN = dict(
    L=4.45, W=1.90, wb=2.55, r_oh=0.93, R=0.342, arch_gap=0.034, tw=0.245, tw_r=0.29, arch_flare=(0.022, 0.12),
    bump_rear=dict(out=0.025, z_top=0.47, z_bot=[(0.0, 0.205), (0.3, 0.15), (0.6, 0.125)], r_plan=0.32, p_plan=2.4,
                   r_end_bot=0.04),
    bump_front=dict(out=0.03, z_top=0.44, z_bot=[(3.9, 0.13), (4.45, 0.15)], r_plan=0.55, r_end_bot=0.06),
    plan=[(0.0, 0.90), (0.5, 0.94), (0.93, 0.95), (1.6, 0.912), (2.6, 0.908), (3.48, 0.935), (4.45, 0.885)],
    r_plan=(0.28, 0.52), p_plan=(2.4, 2.0),
    deck=[(0.03, 0.885), (0.25, 0.90), (0.6, 0.90), (1.5, 0.88), (2.8, 0.86), (3.2, 0.84), (3.7, 0.79), (4.1, 0.70),
          (4.42, 0.60)],
    crown=[(0.0, 0.03), (3.0, 0.03), (3.4, 0.04), (4.45, 0.035)],
    r_top=(0.055, 0.17), r_bot=(0.05, 0.08),
    under=[(0.0, 0.205), (0.3, 0.14), (0.8, 0.115), (3.9, 0.115), (4.2, 0.135), (4.45, 0.16)],
    shoulder=[(0.0, 0.75), (1.0, 0.76), (2.5, 0.72), (4.45, 0.67)],
    tuck=0.06, tumble_up=0.05, r_edge=0.08, r_bottom=0.045,
    g_range=(0.30, 3.25),
    roof=[(0.30, 0.85), (0.38, 0.93), (0.6, 1.015), (0.95, 1.105), (1.35, 1.18), (1.75, 1.225), (2.2, 1.232),
          (2.5, 1.205), (2.75, 1.13), (3.0, 1.0), (3.25, 0.84)],
    g_inset=0.05, tumble=0.42, r_roof=0.07, roof_crown=0.04,
    roof_taper=[(0.3, 0.10), (0.8, 0.05), (1.4, 0.0), (2.4, 0.0), (3.2, 0.03)],
    wheel_inset=0.018,
    rims=dict(color="#16171a", metal=0.5, rough=0.2, coat=0.9, spokes=5, kind="y", spoke_w=(0.06, 0.03),
              dish=0.045, caliper="#d8b01c"),
    glass=dict(dlo=dict(y_rear=1.30, y_rear_top=1.62, y_front=3.15, top=0.022, bottom=0.012, pillars=[]),
               ws=dict(bottom=3.12, top=2.56, pillar=0.055),
               rw=dict(bottom=0.42, top=1.30, pillar=0.08, proj="top")),
)

GRAN_TURISMO = dict(
    L=4.95, W=1.95, wb=2.90, r_oh=0.95, R=0.35, arch_gap=0.034, tw=0.255, tw_r=0.295, arch_flare=(0.015, 0.11),
    bump_rear=dict(out=0.025, z_top=0.49, z_bot=[(0.0, 0.21), (0.3, 0.16), (0.7, 0.13)], r_plan=0.34, p_plan=2.3,
                   r_end_bot=0.04),
    bump_front=dict(out=0.03, z_top=0.46, z_bot=[(4.3, 0.14), (4.95, 0.16)], r_plan=0.58, r_end_bot=0.06),
    plan=[(0.0, 0.93), (0.95, 0.975), (1.8, 0.95), (2.9, 0.945), (3.85, 0.965), (4.95, 0.92)],
    r_plan=(0.30, 0.55), p_plan=(2.3, 2.0),
    deck=[(0.03, 0.935), (0.14, 0.94), (0.4, 0.925), (0.8, 0.915), (2.0, 0.90), (3.0, 0.895), (3.4, 0.885),
          (3.9, 0.85), (4.4, 0.78), (4.8, 0.69), (4.92, 0.64)],
    crown=[(0.0, 0.03), (3.0, 0.03), (3.4, 0.045), (4.95, 0.04)],
    r_top=(0.045, 0.18), r_bot=(0.05, 0.08),
    under=[(0.0, 0.21), (0.3, 0.15), (0.8, 0.125), (4.3, 0.125), (4.6, 0.14), (4.95, 0.17)],
    shoulder=[(0.0, 0.79), (1.0, 0.80), (3.0, 0.76), (4.95, 0.71)],
    tuck=0.06, tumble_up=0.045, r_edge=0.075, r_bottom=0.045,
    g_range=(0.35, 3.10),
    roof=[(0.35, 0.89), (0.45, 0.95), (0.75, 1.05), (1.1, 1.15), (1.5, 1.225), (1.9, 1.275), (2.3, 1.285),
          (2.6, 1.26), (2.85, 1.165), (3.0, 1.03), (3.10, 0.88)],
    g_inset=0.05, tumble=0.40, r_roof=0.075, roof_crown=0.04,
    roof_taper=[(0.35, 0.10), (0.9, 0.05), (1.5, 0.0), (2.5, 0.0), (3.05, 0.03)],
    wheel_inset=0.018,
    rims=dict(color="#c4c8cd", metal=1.0, rough=0.18, coat=0.5, spokes=10, kind="turbine", spoke_w=(0.034, 0.024),
              bend=14.0, dish=0.03, caliper="#24262a"),
    glass=dict(dlo=dict(y_rear=1.38, y_rear_top=1.72, y_front=3.0, top=0.022, bottom=0.012, pillars=[]),
               ws=dict(bottom=2.98, top=2.40, pillar=0.055),
               rw=dict(bottom=0.47, top=1.38, pillar=0.08, proj="top")),
)

DESIGNS = {"kompakt": KOMPAKT, "kombi": KOMBI, "limousine": LIMOUSINE, "sportwagen": SPORTWAGEN,
           "gran_turismo": GRAN_TURISMO}


# ---------------------------------------------------------------------------------------------- helpers

def seam(car, pts, proj="side", sym=True, width=0.0045, target="all"):
    m = car.mat("seam", "#070708", rough=0.6, spec=0.2)
    return car.stripe(pts, width, proj, m, offset=0.0007, res=0.004, sym=sym, name="seam", target=target)


def ring(car, outline, width, proj, mat, offset, sym=True, target="all", name="ring"):
    pts = list(outline) + [outline[0]]
    return car.stripe(pts, width, proj, mat, offset=offset, res=min(0.004, width * 0.6), sym=sym, name=name,
                      target=target)


def handle(car, y, z, w=0.135, h=0.026, mat=None):
    rec = car.mat("handle_rec", "#0b0b0c", rough=0.5)
    car.patch(C.rounded_rect(y, z, w + 0.016, h + 0.012, 0.01, 4), "side", rec, offset=0.0008, res=0.006,
              name="handle_rec", target="body")
    car.patch(C.rounded_rect(y, z + 0.002, w, h * 0.7, 0.009, 4), "side", mat or car.paint, offset=0.0055,
              res=0.006, walls=0.0055, wall_mat=mat or car.paint, name="handle", target="body")


def side_skirt(car, z_top, mat, y0=None, y1=None):
    y0 = car.y_ra + car.Ra + 0.03 if y0 is None else y0
    y1 = car.y_fa - car.Ra - 0.03 if y1 is None else y1
    pts = [(y0, 0.05), (y1, 0.05), (y1, z_top), (y0 + 0.02, z_top)]
    return car.patch(pts, "side", mat, offset=0.0015, res=0.012, name="skirt", target="body")


def roof_patch(car, y0, y1, mat, edge=0.45, name="roof_black"):
    right = []
    for i in range(41):
        y = y0 + (y1 - y0) * i / 40
        gh = car.green_half(y)[1]
        right.append((gh["x_rc"] + gh["rr"] * edge, y))
    poly = right + [(-x, y) for (x, y) in reversed(right)]
    return car.patch(poly, "top", mat, offset=0.0012, res=0.02, sym=False, name=name, target="green")


def emblem(car, center, proj, mat, rx=0.05, rz=0.022, text="CE", th=0.026):
    e = C.ellipse(center[0], center[1], rx, rz, 40)
    ring(car, e, 0.006, proj, mat, 0.0035, sym=False, name="emblem")
    CD.text_patch(car, text, th, center, proj, mat, offset=0.0032)


def grille_mat(car, kind="honeycomb", base="#0b0b0c", rim="#2a2b2e", scale=34.0):
    """Mesh / slatted grille shader in object space (crisp at any size)."""
    m, nb = M.new_material(car.name + "_grille_" + kind)
    if kind == "slats":
        x, y, z = nb.coords()
        f = nb.math("FRACT", nb.mul(z, scale))
        mask = nb.gt(f, 0.42)
    else:
        tex = nb.node("ShaderNodeTexBrick")
        tex.offset = 0.5
        tex.inputs["Scale"].default_value = scale
        tex.inputs["Mortar Size"].default_value = 0.05
        tex.inputs["Brick Width"].default_value = 0.6
        tex.inputs["Row Height"].default_value = 0.3
        tc = nb.node("ShaderNodeTexCoord")
        mp = nb.node("ShaderNodeMapping")
        mp.inputs["Rotation"].default_value = (1.5708, 0.0, 0.0)
        nb.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        nb.links.new(mp.outputs["Vector"], tex.inputs["Vector"])
        mask = tex.outputs["Fac"]
    col = nb.mix(mask, M.srgb(base), M.srgb(rim))
    rough = nb.mixf(mask, 0.6, 0.3)
    out = M.principled(nb, col, rough=rough, metal=0.2, spec=0.4)
    return M.finish(m, nb, out, None)


def headlight(car, outline, parts, tag="head", tint="#dfe6ec"):
    CD.lamp(car, dict(outline=outline, proj="front", tint=tint, depth=0.01, housing="#101113", frost=0.0,
                      parts=parts), tag=tag)


def standard_side(car, d, mats, seams, handles, mirror, skirt=0.27, fuel=None):
    if skirt:
        side_skirt(car, skirt, mats["plastic"])
    for path in seams:
        seam(car, path)
    for (y, z) in handles:
        handle(car, y, z)
    if fuel:
        y, z = fuel
        ring(car, C.rounded_rect(y, z, 0.15, 0.11, 0.025, 4), 0.004, "side", car.mat("seam", "#070708", rough=0.6),
             0.0007, sym=False, name="fuelflap")
    y, z, mm = mirror
    CD.mirrors(car, y, z, mm)


def materials_for(car):
    return dict(
        black=M.basic(car.name + "_gloss_black", "#060607", rough=0.06, coat=1.0, spec=0.6),
        plastic=car.mat("plastic", "#141516", rough=0.55, spec=0.35),
        chrome=car.mat("chrome", "#e0e2e5", rough=0.08, metal=1.0),
        satin=car.mat("satin", "#9a9ea4", rough=0.3, metal=1.0),
        carbon=M.basic(car.name + "_carbon", "#16171a", rough=0.18, coat=1.0, metal=0.3),
    )


def brake3_mat(car):
    return M.basic(car.name + "_brake3", "#4a0806", rough=0.2, coat=0.6, emit={"brake": (CD.BRAKE_RED, 1.0)})


def spoiler_x(car, hw, y_le, y_te, z_le, z_te, thick, mat, name="spoiler", n=13, droop=0.03, tip=0.55):
    secs = []
    for i in range(n):
        t = -1.0 + 2.0 * i / (n - 1)
        k = 1.0 - max(0.0, abs(t) - 0.86) / 0.14 * tip
        secs.append((hw * t, CD.airfoil(y_le, y_te + 0.04 * abs(t) ** 4, z_le - droop * abs(t) ** 3,
                                        z_te - droop * abs(t) ** 3, thick * k, camber=0.005)))
    return CD.loft_x(car, secs, mat, name)


# ---------------------------------------------------------------------------------------------- kompakt

def features_kompakt(car, d, mats):
    black, plastic, chrome = mats["black"], mats["plastic"], mats["chrome"]
    roof_patch(car, 0.40, 2.22, black)
    spoiler_x(car, 0.66, 0.66, 0.27, car.roof(0.66) - 0.012, car.roof(0.66) - 0.05, 0.05, black)
    CD.light_box(car, (0.0, 0.285, car.roof(0.66) - 0.07), (0.34, 0.012, 0.012), brake3_mat(car), bevel=0.003,
                 name="brake3")
    outline = [(0.40, 0.842), (0.80, 0.792), (0.872, 0.80), (0.872, 0.935), (0.40, 0.918)]
    CD.lamp(car, dict(
        outline=outline, tint="#c41a0f", depth=0.011,
        parts=[
            dict(kind="tail", outline=[(0.43, 0.852), (0.80, 0.806), (0.86, 0.812), (0.86, 0.922), (0.43, 0.905)], tail=0.22),
            dict(kind="chrome", outline=C.rounded_rect(0.64, 0.858, 0.20, 0.05, 0.02, 4)),
            dict(kind="brake", outline=C.rounded_rect(0.64, 0.858, 0.17, 0.034, 0.016, 4), brake=1.0),
            dict(kind="guide", path=[(0.44, 0.902), (0.62, 0.908), (0.80, 0.914), (0.85, 0.905), (0.855, 0.83)],
                 width=0.012),
            dict(kind="guide", path=[(0.47, 0.862), (0.53, 0.858)], width=0.01, smooth=False),
        ]), tag="tail")
    car.patch([(-0.405, 0.848), (0.405, 0.848), (0.405, 0.905), (-0.405, 0.905)], "rear", black, offset=0.0012,
              res=0.01, sym=False, name="tailband")
    emblem(car, (0.0, 0.877), "rear", chrome)
    CD.text_patch(car, "KOMPAKT GTX", 0.026, (0.33, 0.585), "rear", chrome, offset=0.0025)
    CD.plate(car, (0.0, 0.66), text="K·CE 410", target="body")
    for x in (0.47, -0.47):
        seam(car, [(x, 0.54), (x, 0.79)], proj="rear", sym=False)
    diff = [(-0.64, 0.268), (0.64, 0.268), (0.66, 0.37), (0.22, 0.385), (-0.22, 0.385), (-0.66, 0.37)]
    car.patch(diff, "rear", plastic, offset=0.0015, res=0.01, sym=False, name="diffuser", target="bumper_rear")
    CD.fins(car, [0.19, 0.30, 0.41], 0.24, 0.335, -0.004, 0.22, sym=True)
    CD.exhaust(car, 0.078, 0.30, "round", r=0.043, y_tip=-0.016)
    CD.lamp(car, dict(outline=C.rounded_rect(0.67, 0.425, 0.13, 0.024, 0.008, 3), depth=0.006, tint="#8c120a",
                      parts=[dict(kind="reflector", outline=C.rounded_rect(0.67, 0.425, 0.12, 0.018, 0.006, 3))],
                      target="bumper_rear"), tag="refl")
    CD.lamp(car, dict(outline=C.rounded_rect(-0.47, 0.335, 0.09, 0.03, 0.01, 3), depth=0.006, tint="#a01208", sym=False,
                      parts=[dict(kind="dark", outline=C.rounded_rect(-0.47, 0.335, 0.08, 0.022, 0.008, 3))],
                      target="bumper_rear"), tag="fog")
    CD.lamp(car, dict(outline=C.rounded_rect(0.47, 0.335, 0.09, 0.03, 0.01, 3), depth=0.006, tint="#e8eaee", sym=False,
                      parts=[dict(kind="white", outline=C.rounded_rect(0.47, 0.335, 0.08, 0.022, 0.008, 3))],
                      target="bumper_rear"), tag="reverse")
    standard_side(car, d, mats,
                  seams=[[(2.875, 0.975), (2.875, 0.27)], [(1.99, 0.975), (1.99, 0.27)],
                         [(1.13, 0.975), (1.13, 0.66), (1.05, 0.585), (1.03, 0.45)]],
                  handles=[(2.38, 0.885), (1.47, 0.885)], mirror=(2.86, 1.035, black), fuel=(0.50, 0.765))
    p0 = car.cast("rear", 0.0, 1.03, target="green")
    p1 = car.cast("rear", -0.31, 1.24, target="green")
    if p0 and p1:
        CD.wiper(car, tuple(p0[0] + p0[1] * 0.014), tuple(p1[0] + p1[1] * 0.012))
    # front: slim upper grille with red pinstripe, honeycomb intake, swept headlights with DRL hook
    headlight(car, [(0.40, 0.652), (0.74, 0.628), (0.845, 0.655), (0.855, 0.70), (0.42, 0.712)], [
        dict(kind="chrome", outline=[(0.43, 0.66), (0.74, 0.64), (0.83, 0.662), (0.84, 0.695), (0.44, 0.702)]),
        dict(kind="dark", outline=C.ellipse(0.55, 0.678, 0.034, 0.024, 24)),
        dict(kind="dark", outline=C.ellipse(0.66, 0.672, 0.034, 0.024, 24)),
        dict(kind="white", path=[(0.43, 0.664), (0.72, 0.645), (0.82, 0.66), (0.835, 0.69)], width=0.011),
    ])
    car.patch([(-0.40, 0.615), (0.40, 0.615), (0.415, 0.668), (-0.415, 0.668)], "front", grille_mat(car), offset=0.0015,
              res=0.01, sym=False, name="grille")
    car.stripe([(-0.41, 0.652), (0.41, 0.652)], 0.007, "front", car.mat("red_pin", "#d01418", rough=0.3, coat=0.6),
               offset=0.003, res=0.004, sym=False, name="pinstripe")
    car.patch([(-0.60, 0.275), (0.60, 0.275), (0.67, 0.468), (-0.67, 0.468)], "front", grille_mat(car), offset=0.0015,
              res=0.012, sym=False, name="intake", target="bumper_front")
    ring(car, [(-0.60, 0.275), (0.60, 0.275), (0.67, 0.468), (-0.67, 0.468)], 0.012, "front", black, 0.003, sym=False,
         name="intake_frame", target="bumper_front")
    for x in (0.755, -0.755):
        car.patch(C.rounded_rect(x, 0.36, 0.05, 0.13, 0.015, 3), "front", black, offset=0.002, res=0.006, sym=False,
                  name="curtain", target="bumper_front")
    emblem(car, (0.0, 0.64), "front", chrome, rx=0.045, rz=0.02, th=0.022)
    CD.plate(car, (0.0, 0.37), proj="front", text="K·CE 410", target="bumper_front", recess=0.0)
    for x in (0.70, -0.70):
        seam(car, [(x, 2.98), (x * 0.99, 3.6), (x * 0.95, 3.95)], proj="top", sym=False)


# ---------------------------------------------------------------------------------------------- kombi

def features_kombi(car, d, mats):
    black, plastic, chrome, satin = mats["black"], mats["plastic"], mats["chrome"], mats["satin"]
    CD.roof_rails(car, 0.36, 2.70, 0.10, satin)
    spoiler_x(car, 0.62, 0.40, 0.17, car.roof(0.40) - 0.008, car.roof(0.40) - 0.03, 0.04, car.paint, droop=0.02)
    CD.light_box(car, (0.0, 0.165, car.roof(0.40) - 0.045), (0.30, 0.012, 0.012), brake3_mat(car), bevel=0.003,
                 name="brake3")
    # L-shaped D-pillar lamps: vertical on the corner, arm along the top into the tailgate
    outline = [(0.52, 0.885), (0.74, 0.885), (0.775, 0.62), (0.905, 0.62), (0.905, 0.985), (0.52, 0.975)]
    CD.lamp(car, dict(
        outline=outline, tint="#c41a0f", depth=0.012,
        parts=[
            dict(kind="tail", outline=[(0.79, 0.64), (0.89, 0.64), (0.89, 0.965), (0.79, 0.955)], tail=0.2),
            dict(kind="chrome", outline=C.rounded_rect(0.84, 0.74, 0.08, 0.12, 0.02, 4)),
            dict(kind="brake", outline=C.rounded_rect(0.84, 0.74, 0.06, 0.10, 0.02, 4), brake=1.0),
            dict(kind="guide", path=[(0.54, 0.952), (0.70, 0.955), (0.86, 0.958), (0.875, 0.93), (0.88, 0.66)],
                 width=0.012),
            dict(kind="guide", path=[(0.56, 0.912), (0.74, 0.915), (0.80, 0.90)], width=0.009),
            dict(kind="white", outline=C.rounded_rect(0.84, 0.655, 0.07, 0.03, 0.01, 3), offset=0.0042),
        ]), tag="tail")
    car.stripe([(-0.51, 0.80), (0.51, 0.80)], 0.018, "rear", chrome, offset=0.0025, res=0.005, sym=False,
               name="chromestrip")
    emblem(car, (0.0, 0.90), "rear", chrome)
    CD.text_patch(car, "KOMBI", 0.028, (0.36, 0.585), "rear", chrome, offset=0.0025)
    CD.text_patch(car, "4MOTION", 0.022, (-0.36, 0.585), "rear", chrome, offset=0.0025)
    CD.plate(car, (0.0, 0.672), text="KB·CE 480", target="body")
    for x in (0.53, -0.53):
        seam(car, [(x, 0.545), (x, 0.875)], proj="rear", sym=False)
    car.patch([(-0.70, 0.27), (0.70, 0.27), (0.72, 0.36), (-0.72, 0.36)], "rear", plastic, offset=0.0015, res=0.01,
              sym=False, name="diffuser", target="bumper_rear")
    car.stripe([(-0.66, 0.285), (0.66, 0.285)], 0.022, "rear", satin, offset=0.0028, res=0.006, sym=False,
               name="diffuser_lip", target="bumper_rear")
    CD.exhaust(car, 0.53, 0.315, "trapezoid", w=0.15, h=0.05, y_tip=-0.012, corner=0.012)
    CD.lamp(car, dict(outline=C.rounded_rect(0.79, 0.43, 0.10, 0.022, 0.008, 3), depth=0.006, tint="#8c120a",
                      parts=[dict(kind="reflector", outline=C.rounded_rect(0.79, 0.43, 0.09, 0.016, 0.006, 3))],
                      target="bumper_rear"), tag="refl")
    standard_side(car, d, mats,
                  seams=[[(3.56, 0.975), (3.56, 0.27)], [(2.34, 0.975), (2.34, 0.27)],
                         [(1.30, 0.975), (1.30, 0.70), (1.36, 0.62), (1.36, 0.45)]],
                  handles=[(3.02, 0.90), (1.84, 0.90)], mirror=(3.56, 1.04, car.paint), fuel=(0.70, 0.79))
    p0 = car.cast("rear", 0.0, 1.03, target="green")
    p1 = car.cast("rear", -0.33, 1.30, target="green")
    if p0 and p1:
        CD.wiper(car, tuple(p0[0] + p0[1] * 0.014), tuple(p1[0] + p1[1] * 0.012))
    # front: chrome-slatted grille, slim lamps
    headlight(car, [(0.44, 0.70), (0.80, 0.675), (0.875, 0.70), (0.87, 0.745), (0.46, 0.76)], [
        dict(kind="chrome", outline=[(0.47, 0.707), (0.79, 0.685), (0.86, 0.705), (0.855, 0.738), (0.48, 0.75)]),
        dict(kind="dark", outline=C.ellipse(0.60, 0.722, 0.032, 0.022, 24)),
        dict(kind="dark", outline=C.ellipse(0.71, 0.716, 0.032, 0.022, 24)),
        dict(kind="white", path=[(0.47, 0.745), (0.80, 0.735), (0.86, 0.712)], width=0.01),
    ])
    car.patch([(-0.42, 0.56), (0.42, 0.56), (0.44, 0.72), (-0.44, 0.72)], "front", grille_mat(car, "slats", "#0c0c0d",
              "#c9ccd0", 46.0), offset=0.0015, res=0.01, sym=False, name="grille")
    ring(car, [(-0.42, 0.56), (0.42, 0.56), (0.44, 0.72), (-0.44, 0.72)], 0.012, "front", chrome, 0.003, sym=False,
         name="grille_frame")
    car.patch([(-0.55, 0.22), (0.55, 0.22), (0.60, 0.36), (-0.60, 0.36)], "front", grille_mat(car), offset=0.0015,
              res=0.012, sym=False, name="intake", target="bumper_front")
    emblem(car, (0.0, 0.64), "front", chrome, rx=0.05, rz=0.024, th=0.024)
    CD.plate(car, (0.0, 0.43), proj="front", text="KB·CE 480", target="bumper_front", recess=0.0)
    for x in (0.73, -0.73):
        seam(car, [(x, 3.68), (x * 0.99, 4.3), (x * 0.95, 4.65)], proj="top", sym=False)


# ---------------------------------------------------------------------------------------------- limousine

def features_limousine(car, d, mats):
    black, plastic, chrome, satin = mats["black"], mats["plastic"], mats["chrome"], mats["satin"]
    # small body-coloured lip on the trunk edge
    spoiler_x(car, 0.62, 0.20, 0.035, 1.04, 1.055, 0.022, car.paint, droop=0.01, tip=0.8, name="lip")
    # corner lamps + full-width light bar
    outline = [(0.52, 0.89), (0.84, 0.845), (0.918, 0.86), (0.918, 0.985), (0.52, 0.975)]
    CD.lamp(car, dict(
        outline=outline, tint="#c41a0f", depth=0.011,
        parts=[
            dict(kind="tail", outline=[(0.55, 0.897), (0.84, 0.857), (0.905, 0.87), (0.905, 0.972), (0.55, 0.965)], tail=0.2),
            dict(kind="chrome", outline=C.rounded_rect(0.74, 0.912, 0.24, 0.05, 0.02, 4)),
            dict(kind="brake", outline=C.rounded_rect(0.74, 0.912, 0.21, 0.032, 0.014, 4), brake=1.0),
            dict(kind="guide", path=[(0.53, 0.958), (0.72, 0.962), (0.88, 0.966), (0.905, 0.94), (0.90, 0.875)],
                 width=0.011),
            dict(kind="guide", path=[(0.56, 0.902), (0.82, 0.866)], width=0.008),
        ]), tag="tail")
    bar = [(-0.52, 0.935), (0.52, 0.935), (0.52, 0.957), (-0.52, 0.957)]
    CD.lamp(car, dict(outline=bar, sym=False, tint="#c41a0f", depth=0.009, parts=[
        dict(kind="guide", path=[(-0.515, 0.946), (0.515, 0.946)], width=0.008, smooth=False, tail=0.9, brake=0.5)]),
        tag="bar")
    emblem(car, (0.0, 0.885), "rear", chrome)
    CD.text_patch(car, "LIMOUSINE", 0.026, (0.36, 0.835), "rear", chrome, offset=0.0025)
    CD.text_patch(car, "V6", 0.026, (-0.40, 0.835), "rear", chrome, offset=0.0025)
    car.stripe([(-0.50, 0.785), (0.50, 0.785)], 0.016, "rear", chrome, offset=0.0025, res=0.005, sym=False,
               name="trunkchrome")
    CD.plate(car, (0.0, 0.69), text="L·CE 485", target="body")
    car.stripe([(-0.60, 0.50), (0.60, 0.50)], 0.012, "rear", chrome, offset=0.0025, res=0.005, sym=False,
               name="chromestrip", target="bumper_rear")
    seam(car, [(-0.80, 0.83), (-0.80, 0.60), (0.80, 0.60), (0.80, 0.83)], proj="rear", sym=False)
    car.patch([(-0.76, 0.265), (0.76, 0.265), (0.78, 0.34), (-0.78, 0.34)], "rear", plastic, offset=0.0015, res=0.01,
              sym=False, name="diffuser", target="bumper_rear")
    CD.exhaust(car, 0.58, 0.30, "rect", w=0.17, h=0.048, y_tip=-0.012, corner=0.014)
    CD.fins(car, [0.22, 0.33], 0.235, 0.32, -0.004, 0.2, sym=True)
    CD.lamp(car, dict(outline=C.rounded_rect(0.80, 0.44, 0.09, 0.02, 0.008, 3), depth=0.006, tint="#8c120a",
                      parts=[dict(kind="reflector", outline=C.rounded_rect(0.80, 0.44, 0.08, 0.014, 0.006, 3))],
                      target="bumper_rear"), tag="refl")
    standard_side(car, d, mats,
                  seams=[[(3.64, 0.975), (3.64, 0.27)], [(2.45, 0.975), (2.45, 0.27)],
                         [(1.50, 0.975), (1.50, 0.70), (1.42, 0.62), (1.40, 0.45)]],
                  handles=[(3.10, 0.93), (1.96, 0.93)], mirror=(3.64, 1.06, car.paint), fuel=(0.62, 0.82))
    # trunk lid shut lines (top view)
    seam(car, [(0.80, 0.05), (0.80, 0.94)], proj="top", sym=True)
    headlight(car, [(0.46, 0.69), (0.82, 0.665), (0.895, 0.69), (0.89, 0.735), (0.48, 0.75)], [
        dict(kind="chrome", outline=[(0.49, 0.697), (0.81, 0.675), (0.88, 0.695), (0.875, 0.728), (0.50, 0.74)]),
        dict(kind="dark", outline=C.ellipse(0.62, 0.712, 0.032, 0.022, 24)),
        dict(kind="dark", outline=C.ellipse(0.73, 0.706, 0.032, 0.022, 24)),
        dict(kind="white", path=[(0.49, 0.737), (0.82, 0.724), (0.88, 0.70)], width=0.01),
    ])
    car.patch([(-0.38, 0.52), (0.38, 0.52), (0.40, 0.71), (-0.40, 0.71)], "front", grille_mat(car, "slats", "#0a0a0b",
              "#3a3d41", 40.0), offset=0.0015, res=0.01, sym=False, name="grille")
    ring(car, [(-0.38, 0.52), (0.38, 0.52), (0.40, 0.71), (-0.40, 0.71)], 0.014, "front", chrome, 0.003, sym=False,
         name="grille_frame")
    car.patch([(-0.52, 0.22), (0.52, 0.22), (0.56, 0.34), (-0.56, 0.34)], "front", grille_mat(car), offset=0.0015,
              res=0.012, sym=False, name="intake", target="bumper_front")
    emblem(car, (0.0, 0.64), "front", chrome, rx=0.05, rz=0.024, th=0.024)
    CD.plate(car, (0.0, 0.42), proj="front", text="L·CE 485", target="bumper_front", recess=0.0)
    for x in (0.74, -0.74):
        seam(car, [(x, 3.80), (x * 0.99, 4.35), (x * 0.95, 4.70)], proj="top", sym=False)


# ---------------------------------------------------------------------------------------------- sportwagen

def features_sportwagen(car, d, mats):
    black, plastic, chrome, carbon = mats["black"], mats["plastic"], mats["chrome"], mats["carbon"]
    # rear wing on two swan-neck pylons
    zw = 1.10
    spoiler_x(car, 0.80, 0.34, 0.06, zw + 0.012, zw - 0.02, 0.05, carbon, droop=0.0, tip=0.2, name="wing")
    for x in (0.80, -0.80):
        CD.light_box(car, (x * 1.002, 0.20, zw - 0.02), (0.012, 0.34, 0.13), carbon, bevel=0.004, name="endplate")
    for x in (0.42, -0.42):
        h = car.cast("top", x, 0.22, target="body")
        z0 = h[0].z if h else 0.88
        CD.light_box(car, (x, 0.22, (z0 + zw) / 2 - 0.005), (0.022, 0.08, zw - z0 - 0.01), carbon, bevel=0.006,
                     name="pylon")
    CD.light_box(car, (0.0, 0.40 - 0.02, car.roof(0.40) - 0.02), (0.22, 0.012, 0.012), brake3_mat(car), bevel=0.003,
                 name="brake3")
    # twin round lamps per side (rings) on a dark panel
    for i, (cx, r) in enumerate(((0.79, 0.082), (0.575, 0.076))):
        o = C.ellipse(cx, 0.775, r, r * 0.92, 40)
        CD.lamp(car, dict(
            outline=o, tint="#c41a0f", depth=0.012,
            parts=[
                dict(kind="tail", outline=C.ellipse(cx, 0.775, r * 0.92, r * 0.85, 40), tail=0.18),
                dict(kind="chrome", outline=C.ellipse(cx, 0.775, r * 0.62, r * 0.57, 32)),
                dict(kind="brake", outline=C.ellipse(cx, 0.775, r * 0.42, r * 0.39, 32), brake=1.0),
                dict(kind="guide", path=C.ellipse(cx, 0.775, r * 0.78, r * 0.72, 40) +
                     [C.ellipse(cx, 0.775, r * 0.78, r * 0.72, 40)[0]], width=0.011, smooth=False),
            ]), tag="ring%d" % i)
    car.patch([(-0.46, 0.72), (0.46, 0.72), (0.48, 0.83), (-0.48, 0.83)], "rear", grille_mat(car, scale=30.0),
              offset=0.0015, res=0.01, sym=False, name="rear_mesh")
    emblem(car, (0.0, 0.865), "rear", chrome, rx=0.045, rz=0.02, th=0.022)
    CD.text_patch(car, "SPORTWAGEN", 0.024, (0.0, 0.615), "rear", chrome, offset=0.0025)
    CD.plate(car, (0.0, 0.40), text="S·CE 455", target="bumper_rear")
    diff = [(-0.74, 0.215), (0.74, 0.215), (0.78, 0.33), (0.35, 0.34), (-0.35, 0.34), (-0.78, 0.33)]
    car.patch(diff, "rear", carbon, offset=0.0015, res=0.01, sym=False, name="diffuser", target="bumper_rear")
    CD.fins(car, [0.11, 0.22, 0.56], 0.175, 0.27, 0.004, 0.3, thick=0.008, mat=carbon, sym=True)
    for x in (0.30, 0.42):
        CD.exhaust(car, x, 0.265, "round", r=0.04, y_tip=-0.02)
    CD.lamp(car, dict(outline=C.rounded_rect(0.84, 0.40, 0.08, 0.018, 0.007, 3), depth=0.006, tint="#8c120a",
                      parts=[dict(kind="reflector", outline=C.rounded_rect(0.84, 0.40, 0.07, 0.012, 0.005, 3))],
                      target="bumper_rear"), tag="refl")
    standard_side(car, d, mats,
                  seams=[[(3.12, 0.90), (3.12, 0.24)], [(1.92, 0.90), (1.85, 0.40), (1.86, 0.24)]],
                  handles=[(2.02, 0.83)], mirror=(3.10, 0.905, car.paint), skirt=0.24, fuel=(0.55, 0.74))
    # side intake in front of the rear wheel
    car.patch([(1.40, 0.42), (1.80, 0.50), (1.80, 0.58), (1.35, 0.55)], "side", grille_mat(car, scale=26.0),
              offset=0.0015, res=0.008, name="side_intake", target="body")
    headlight(car, [(0.44, 0.60), (0.80, 0.58), (0.86, 0.60), (0.84, 0.645), (0.46, 0.655)], [
        dict(kind="chrome", outline=[(0.47, 0.607), (0.79, 0.588), (0.85, 0.606), (0.83, 0.638), (0.48, 0.646)]),
        dict(kind="dark", outline=C.ellipse(0.62, 0.62, 0.03, 0.02, 24)),
        dict(kind="white", path=[(0.47, 0.641), (0.80, 0.63), (0.845, 0.605)], width=0.01),
    ])
    car.patch([(-0.62, 0.17), (0.62, 0.17), (0.70, 0.40), (0.40, 0.42), (-0.40, 0.42), (-0.70, 0.40)], "front",
              grille_mat(car), offset=0.0015, res=0.012, sym=False, name="intake", target="bumper_front")
    car.patch([(-0.78, 0.14), (0.78, 0.14), (0.80, 0.175), (-0.80, 0.175)], "front", carbon, offset=0.003, res=0.01,
              sym=False, name="splitter", target="bumper_front")
    emblem(car, (0.0, 0.57), "front", chrome, rx=0.045, rz=0.02, th=0.022)
    CD.plate(car, (0.0, 0.33), proj="front", text="S·CE 455", target="bumper_front", recess=0.0)
    for x in (0.62, -0.62):
        seam(car, [(x, 3.30), (x * 0.98, 3.9), (x * 0.9, 4.3)], proj="top", sym=False)


# ---------------------------------------------------------------------------------------------- gran turismo

def features_gran_turismo(car, d, mats):
    black, plastic, chrome, satin = mats["black"], mats["plastic"], mats["chrome"], mats["satin"]
    CD.light_box(car, (0.0, 0.47 - 0.01, car.roof(0.47) - 0.012), (0.26, 0.012, 0.01), brake3_mat(car), bevel=0.003,
                 name="brake3")
    # slim lamps joined by a thin full-width strip
    outline = [(0.56, 0.855), (0.90, 0.835), (0.955, 0.85), (0.955, 0.905), (0.56, 0.898)]
    CD.lamp(car, dict(
        outline=outline, tint="#c41a0f", depth=0.01,
        parts=[
            dict(kind="tail", outline=[(0.58, 0.861), (0.90, 0.843), (0.94, 0.855), (0.94, 0.895), (0.58, 0.89)], tail=0.2),
            dict(kind="brake", outline=C.rounded_rect(0.78, 0.872, 0.22, 0.022, 0.01, 4), brake=1.0),
            dict(kind="guide", path=[(0.57, 0.887), (0.76, 0.889), (0.93, 0.891), (0.948, 0.86)], width=0.009),
        ]), tag="tail")
    bar = [(-0.56, 0.872), (0.56, 0.872), (0.56, 0.886), (-0.56, 0.886)]
    CD.lamp(car, dict(outline=bar, sym=False, tint="#c41a0f", depth=0.008, parts=[
        dict(kind="guide", path=[(-0.555, 0.879), (0.555, 0.879)], width=0.006, smooth=False, tail=0.9, brake=0.5)]),
        tag="bar")
    car.stripe([(-0.60, 0.835), (0.60, 0.835)], 0.006, "rear", chrome, offset=0.0025, res=0.004, sym=False,
               name="chromeline")
    CD.text_patch(car, "GRAN TURISMO", 0.03, (0.0, 0.795), "rear", chrome, offset=0.0025, spacing=1.35)
    CD.plate(car, (0.0, 0.645), text="GT·CE 495", target="body")
    car.stripe([(-0.66, 0.505), (0.66, 0.505)], 0.01, "rear", chrome, offset=0.0025, res=0.004, sym=False,
               name="bumperchrome", target="all")
    valance = [(-0.80, 0.235), (0.80, 0.235), (0.84, 0.40), (0.60, 0.415), (-0.60, 0.415), (-0.84, 0.40)]
    car.patch(valance, "rear", black, offset=0.0015, res=0.01, sym=False, name="valance", target="bumper_rear")
    car.patch([(-0.78, 0.235), (0.78, 0.235), (0.80, 0.30), (-0.80, 0.30)], "rear", plastic, offset=0.0025, res=0.01,
              sym=False, name="diffuser", target="bumper_rear")
    CD.fins(car, [0.0, 0.18, 0.30], 0.205, 0.29, 0.0, 0.25, thick=0.008, sym=True)
    for x in (0.50, 0.64):
        CD.exhaust(car, x, 0.30, "oval", w=0.11, h=0.06, y_tip=-0.014)
    CD.lamp(car, dict(outline=C.rounded_rect(0.84, 0.43, 0.09, 0.016, 0.007, 3), depth=0.006, tint="#8c120a",
                      parts=[dict(kind="reflector", outline=C.rounded_rect(0.84, 0.43, 0.08, 0.011, 0.005, 3))],
                      target="bumper_rear"), tag="refl")
    standard_side(car, d, mats,
                  seams=[[(3.0, 0.90), (3.0, 0.25)], [(1.82, 0.90), (1.78, 0.40), (1.79, 0.25)]],
                  handles=[(1.95, 0.84)], mirror=(2.98, 0.935, car.paint), skirt=0.25, fuel=(0.62, 0.76))
    # chrome side gills behind the front wheels
    for i in range(3):
        y = 3.32 - i * 0.045
        car.stripe([(y, 0.50), (y - 0.03, 0.66)], 0.012, "side", chrome, offset=0.002, res=0.004, name="gill",
                   target="body")
    headlight(car, [(0.50, 0.60), (0.86, 0.575), (0.925, 0.60), (0.91, 0.64), (0.52, 0.652)], [
        dict(kind="chrome", outline=[(0.53, 0.607), (0.85, 0.585), (0.91, 0.605), (0.90, 0.633), (0.54, 0.643)]),
        dict(kind="dark", outline=C.ellipse(0.66, 0.62, 0.03, 0.02, 24)),
        dict(kind="dark", outline=C.ellipse(0.76, 0.615, 0.03, 0.02, 24)),
        dict(kind="white", path=[(0.53, 0.640), (0.86, 0.628), (0.91, 0.605)], width=0.009),
    ])
    car.patch([(-0.44, 0.30), (0.44, 0.30), (0.50, 0.50), (-0.50, 0.50)], "front", grille_mat(car, "slats", "#0a0a0b",
              "#c4c7cb", 52.0), offset=0.0015, res=0.01, sym=False, name="grille", target="all")
    ring(car, [(-0.44, 0.30), (0.44, 0.30), (0.50, 0.50), (-0.50, 0.50)], 0.012, "front", chrome, 0.003, sym=False,
         name="grille_frame")
    car.patch([(-0.80, 0.15), (0.80, 0.15), (0.82, 0.185), (-0.82, 0.185)], "front", plastic, offset=0.003, res=0.01,
              sym=False, name="splitter", target="bumper_front")
    emblem(car, (0.0, 0.56), "front", chrome, rx=0.045, rz=0.02, th=0.022)
    CD.plate(car, (0.0, 0.24), proj="front", text="GT·CE 495", target="bumper_front", recess=0.0)
    for x in (0.70, -0.70):
        seam(car, [(x, 3.15), (x * 0.99, 4.0), (x * 0.93, 4.75)], proj="top", sym=False)


FEATURES = {"kompakt": features_kompakt, "kombi": features_kombi, "limousine": features_limousine,
            "sportwagen": features_sportwagen, "gran_turismo": features_gran_turismo}


def build(rig, p):
    d = DESIGNS[p["design"]]
    car = CB.SmoothCar(rig, d, paint=p["paint"], metal=p.get("metal", 0.3), name=p["design"])
    car.build_lower()
    car.build_greenhouse()
    car.build_bumpers()
    car.build_liners()
    rims = dict(d["rims"])
    if p.get("showroom"):
        rims["steer"] = 10.0
    CD.wheels(car, rims)
    CD.glass(car, d["glass"])
    FEATURES[p["design"]](car, d, materials_for(car))
    car.finish()
    return dict(object=car.object_size(), car=car)
