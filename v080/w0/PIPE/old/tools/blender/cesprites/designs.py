"""Car designs (dimensions and side profiles in metres, vehicle space: y=0 rear bumper, +y forward).

lower : top line of the lower body (trunk / belt / hood) as (y, z)
cabin : greenhouse silhouette (y, z) from the rear base to the windshield base
win   : window layout (pillars = (y, width) between side windows, clip = extra half-planes)
Lamps/plates/seams are shader decals: polygons in (|x|, z) on rear/front faces or (y, z) on side faces.
"""
import copy


def _wrap(z0, z1, depth=0.2, slant=0.02):
    """Side wrap-around part of a rear lamp (side faces, near the rear end)."""
    return dict(face="side", poly=[(0.0, z0), (depth, z0 + slant), (depth - 0.02, z1), (0.0, z1)])


def _front_wrap(L, z0, z1, depth=0.28):
    return dict(face="side", part="head", poly=[(L - depth, z0 + 0.02), (L + 0.05, z0), (L + 0.05, z1), (L - depth + 0.04, z1)])


def _headlights(x0, x1, z0, z1, L, slant=0.03):
    return [
        dict(face="front", part="head", poly=[(x0, z0 + slant), (x1, z0), (x1, z1), (x0 + 0.04, z1)]),
        _front_wrap(L, z0, z1),
    ]


def _front(x_grille, z_grille, intake=None, fog=None, grille_mat="gloss_black"):
    out = [dict(face="front", poly=[(0.0, z_grille[0]), (x_grille, z_grille[0]), (x_grille - 0.03, z_grille[1]),
                                    (0.0, z_grille[1])], mat=grille_mat)]
    if intake:
        xi, zi = intake
        out.append(dict(face="front", poly=[(0.0, zi[0]), (xi, zi[0]), (xi + 0.03, zi[1]), (0.0, zi[1])], mat="black"))
    if fog:
        xf, zf = fog
        out.append(dict(face="front", poly=[(xf[0], zf[0]), (xf[1], zf[0]), (xf[1], zf[1]), (xf[0], zf[1])], mat="lamp_clear"))
    return out


HATCH = dict(
    L=4.05, W=1.76, wb=2.58, r_oh=0.62, wheel_r=0.31, tire_w=0.205, clearance=0.15,
    lower=[(0.035, 0.93), (0.2, 0.97), (1.2, 0.98), (2.6, 0.96), (3.05, 0.93), (3.6, 0.84), (3.95, 0.74), (4.05, 0.66)],
    cabin=[(0.06, 0.95), (0.10, 1.12), (0.16, 1.30), (0.26, 1.42), (0.45, 1.47), (1.0, 1.48), (2.05, 1.47),
           (2.35, 1.42), (2.6, 1.28), (2.95, 1.02), (3.05, 0.94)],
    tumble=0.22, plan_r=(0.2, 0.36),
    bumper=dict(z=(0.0, 0.55), plastic=0.24), front_bumper_z=(0.0, 0.52),
    plate_on_bumper=True, plate_z=0.35,
    tail_lamps=[
        dict(poly=[(0.50, 0.745), (0.92, 0.72), (0.92, 0.925), (0.56, 0.925)]),
        _wrap(0.72, 0.925, 0.19),
        dict(part="reverse", poly=[(0.50, 0.745), (0.62, 0.74), (0.62, 0.80), (0.51, 0.80)], outline=False),
    ],
    chmsl=(1.34, 1.375, 0.17),
    seams=[0.98, 1.95, 2.97], handles=[(1.12, 0.89), (2.1, 0.89)],
    win=dict(pillars=[(1.95, 0.08)], clip=[((1.12, 1.44), (0.86, 0.98))], rw_pillar=0.11, rw_bottom=0.05),
    extras=dict(exhaust=[(-0.45, 0.2)]),
    mirror_y=2.82,
    head_lamps=_headlights(0.48, 0.86, 0.60, 0.70, 4.05),
    body_decals=_front(0.40, (0.46, 0.58), intake=(0.55, (0.18, 0.30))),
)

SEDAN = dict(
    L=4.70, W=1.82, wb=2.80, r_oh=0.93, wheel_r=0.32, tire_w=0.215, clearance=0.15,
    lower=[(0.035, 0.95), (0.25, 1.0), (1.0, 1.01), (3.3, 0.98), (3.9, 0.92), (4.5, 0.82), (4.70, 0.72)],
    cabin=[(0.95, 0.99), (1.2, 1.18), (1.45, 1.34), (1.7, 1.42), (2.0, 1.45), (2.6, 1.45), (2.95, 1.42),
           (3.2, 1.30), (3.5, 1.08), (3.62, 0.99)],
    tumble=0.22,
    bumper=dict(z=(0.0, 0.56), plastic=0.24), front_bumper_z=(0.0, 0.54),
    plate_on_bumper=True, plate_z=0.33,
    tail_lamps=[
        dict(poly=[(0.47, 0.80), (0.95, 0.785), (0.95, 0.935), (0.50, 0.94)]),
        _wrap(0.785, 0.935, 0.24),
        dict(part="reverse", poly=[(0.47, 0.80), (0.60, 0.797), (0.60, 0.845), (0.475, 0.845)], outline=False),
    ],
    chmsl=(1.30, 1.33, 0.2),
    seams=[1.33, 2.33, 3.38], handles=[(1.5, 0.93), (2.55, 0.93)],
    win=dict(pillars=[(2.33, 0.08)], clip=[((1.78, 1.41), (1.42, 1.02))]),
    extras=dict(exhaust=[(-0.5, 0.2)]),
    mirror_y=3.45,
    head_lamps=_headlights(0.50, 0.88, 0.64, 0.73, 4.70),
    body_decals=_front(0.42, (0.47, 0.62), intake=(0.6, (0.18, 0.30))),
)

WAGON = dict(
    L=4.80, W=1.84, wb=2.80, r_oh=1.0, wheel_r=0.32, tire_w=0.215, clearance=0.15,
    lower=[(0.035, 0.93), (0.25, 0.98), (1.2, 0.99), (3.4, 0.97), (3.95, 0.92), (4.55, 0.82), (4.80, 0.70)],
    cabin=[(0.05, 0.95), (0.09, 1.15), (0.15, 1.36), (0.25, 1.46), (0.45, 1.49), (2.7, 1.48), (3.05, 1.43),
           (3.3, 1.29), (3.65, 1.04), (3.75, 0.96)],
    tumble=0.2, plan_r=(0.18, 0.38),
    bumper=dict(z=(0.0, 0.55), plastic=0.24), front_bumper_z=(0.0, 0.53),
    plate_z=0.60,
    tail_lamps=[
        dict(poly=[(0.52, 0.76), (0.93, 0.74), (0.93, 0.925), (0.60, 0.925)]),
        _wrap(0.74, 0.925, 0.2),
    ],
    cabin_lamps=[dict(poly=[(0.66, 0.96), (0.86, 0.96), (0.84, 1.17), (0.72, 1.17)], tail=1.2, brake=2.6)],
    chmsl=(1.40, 1.43, 0.2),
    seams=[1.33, 2.35, 3.42], handles=[(1.5, 0.92), (2.55, 0.92)],
    win=dict(pillars=[(2.35, 0.08), (1.33, 0.07)], c_pillar=0.2, rw_pillar=0.12, rw_bottom=0.04),
    extras=dict(exhaust=[(-0.5, 0.2)], roof_rails=(0.35, 2.6)),
    mirror_y=3.55,
    head_lamps=_headlights(0.50, 0.89, 0.62, 0.71, 4.80),
    body_decals=_front(0.42, (0.46, 0.60), intake=(0.6, (0.18, 0.30))),
)

SUV = dict(
    L=4.62, W=1.90, wb=2.72, r_oh=0.95, wheel_r=0.37, tire_w=0.235, clearance=0.21,
    lower=[(0.035, 1.06), (0.25, 1.10), (1.2, 1.12), (3.0, 1.10), (3.75, 1.05), (4.4, 0.95), (4.62, 0.84)],
    cabin=[(0.05, 1.08), (0.10, 1.32), (0.17, 1.56), (0.28, 1.68), (0.5, 1.72), (2.6, 1.71), (2.95, 1.64),
           (3.2, 1.50), (3.55, 1.20), (3.65, 1.12)],
    tumble=0.2, plan_r=(0.22, 0.4), cladding=0.47,
    bumper=dict(z=(0.0, 0.64), plastic=0.42), front_bumper_z=(0.0, 0.62),
    plate_z=0.70,
    tail_lamps=[
        dict(poly=[(0.55, 0.92), (0.96, 0.90), (0.96, 1.065), (0.60, 1.065)]),
        _wrap(0.90, 1.065, 0.22),
        dict(part="reflector", poly=[(0.62, 0.50), (0.85, 0.50), (0.85, 0.54), (0.62, 0.54)], outline=False),
    ],
    chmsl=(1.60, 1.635, 0.2),
    seams=[1.3, 2.28, 3.3], handles=[(1.48, 1.04), (2.48, 1.04)],
    win=dict(pillars=[(2.28, 0.09), (1.30, 0.08)], c_pillar=0.2, rw_pillar=0.12, rw_bottom=0.05),
    extras=dict(exhaust=[(-0.55, 0.3), (0.55, 0.3)], roof_rails=(0.4, 2.5), rail_color="#2a2c2f"),
    mirror_y=3.42,
    head_lamps=_headlights(0.52, 0.93, 0.76, 0.86, 4.62),
    body_decals=_front(0.48, (0.52, 0.72), intake=(0.62, (0.24, 0.38))),
    rim_color="#9ea3a9",
)

VAN = dict(
    L=5.40, W=2.02, wb=3.30, r_oh=1.05, wheel_r=0.34, tire_w=0.215, clearance=0.18,
    lower=[(0.035, 1.08), (0.15, 1.10), (3.9, 1.10), (4.3, 1.07), (4.9, 0.98), (5.3, 0.86), (5.40, 0.78)],
    cabin=[(0.05, 1.09), (0.07, 1.6), (0.09, 2.30), (0.16, 2.42), (0.35, 2.46), (3.6, 2.46), (3.85, 2.40),
           (4.05, 2.15), (4.45, 1.35), (4.55, 1.12)],
    tumble=0.05, roof_rc=0.11, plan_r=(0.12, 0.42), r_end=(0.06, 0.14), shoulder_in=0.03,
    bumper=dict(z=(0.0, 0.58), plastic=0.58), front_bumper_z=(0.0, 0.56), black_bumpers=True,
    plate_on_bumper=True, plate_z=0.38,
    tail_lamps=[
        dict(poly=[(0.86, 0.62), (1.02, 0.62), (1.02, 1.07), (0.86, 1.07)]),
        dict(face="side", poly=[(0.0, 0.62), (0.07, 0.62), (0.07, 1.07), (0.0, 1.07)]),
        dict(part="indicator", poly=[(0.87, 0.95), (1.02, 0.95), (1.02, 1.065), (0.87, 1.065)], outline=False),
    ],
    chmsl=(2.33, 2.37, 0.14),
    seams=[1.25, 3.45, 4.35], handles=[(3.6, 1.0)],
    win=dict(pillars=[], clip=[((3.62, 3.0), (3.62, 0.0))], rw_z0=1.6, rw_top=0.22, rw_pillar=0.14, rw_bottom=0.05),
    extras=dict(exhaust=[(-0.62, 0.25)]),
    mirror_y=4.1, mirror_dz=0.25,
    head_lamps=_headlights(0.58, 0.97, 0.82, 0.96, 5.40),
    body_decals=_front(0.48, (0.60, 0.80), intake=(0.7, (0.24, 0.38)), grille_mat="black") + [
        dict(face="rear", poly=[(0.0, 0.58), (0.005, 0.58), (0.005, 2.5), (0.0, 2.5)], mat="seal")],
    cabin_decals=[dict(face="rear", poly=[(0.0, 1.05), (0.006, 1.05), (0.006, 2.5), (0.0, 2.5)], mat="seal", n=0.5)],
    rim_color="#6e7378", spokes=8, spoke_w=0.12,
)

SPORTS = dict(
    L=4.45, W=1.95, wb=2.50, r_oh=0.95, wheel_r=0.34, tire_w=0.245, tire_w_rear=0.29, clearance=0.11,
    lower=[(0.035, 0.80), (0.15, 0.88), (0.55, 0.91), (1.1, 0.90), (2.0, 0.87), (2.8, 0.85), (3.3, 0.83),
           (3.75, 0.80), (4.1, 0.70), (4.35, 0.59), (4.45, 0.52)],
    cabin=[(0.55, 0.90), (0.9, 1.02), (1.3, 1.15), (1.65, 1.22), (2.25, 1.23), (2.55, 1.18), (2.85, 1.04),
           (3.1, 0.88), (3.18, 0.83)],
    tumble=0.32, plan_r=(0.25, 0.45), r_end=(0.1, 0.14), roof_rc=0.08,
    bumper=dict(z=(0.0, 0.48), plastic=0.28), front_bumper_z=(0.0, 0.42),
    plate_on_bumper=True, plate_z=0.31,
    tail_lamps=[
        dict(poly=[(0.0, 0.705), (0.72, 0.705), (0.72, 0.735), (0.0, 0.735)], tail=1.3, brake=2.6, outline=False),
        dict(poly=[(0.66, 0.66), (0.98, 0.64), (0.98, 0.785), (0.70, 0.785)]),
        _wrap(0.64, 0.785, 0.26),
    ],
    seams=[1.95, 3.22], handles=[(2.05, 0.82)],
    win=dict(pillars=[(1.62, 0.05)], c_pillar=0.1, rw_pillar=0.13, rw_bottom=0.04, ws_pillar=0.08),
    extras=dict(exhaust=[(-0.40, 0.22, 0.045), (-0.29, 0.22, 0.045), (0.29, 0.22, 0.045), (0.40, 0.22, 0.045)],
                wing=dict(width=1.5, chord=0.26, y=0.2, z=1.03, base_z=0.88, black=True)),
    mirror_y=2.95,
    head_lamps=_headlights(0.55, 0.92, 0.50, 0.58, 4.45, slant=0.04),
    body_decals=_front(0.0, (0.3, 0.3), intake=(0.75, (0.14, 0.30))),
    rim_color="#2a2c30", spokes=10, spoke_w=0.12,
)


def variant(base, **kw):
    d = copy.deepcopy(base)
    d.update(kw)
    return d


# The player cars are no longer variants of these designs: see player_cars.py (smooth, detailed models).

TRAFFIC_MODELS = {"hatch": HATCH, "sedan": SEDAN, "wagon": WAGON, "suv": SUV, "van": VAN, "sports": SPORTS}
